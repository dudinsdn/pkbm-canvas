class IdentityController < ActionController::API
  include ActionController::Cookies
  before_action :enabled!, except: [:configuration]
  rescue_from IdentityDirectory::Unavailable, OidcClient::Invalid, IdentitySessionStore::Unauthorized, ActiveRecord::RecordNotFound, ActionController::ParameterMissing do
    render json: {error: 'Login belum tersedia atau identitas belum ditautkan. Hubungi pengelola PKBM.'}, status: :unauthorized
  end
  def configuration
    response.headers['Cache-Control'] = 'no-store'
    render json: {enabled: ENV['PKBM_SSO_ENABLED'] == 'true', canonical_base_url: ENV.fetch('PKBM_PUBLIC_BASE_URL')}
  end
  def login
    state = SecureRandom.hex(32)
    IdentityLoginFlow.create!(id: SecureRandom.uuid, state_digest: Digest::SHA256.hexdigest(state), expires_at: 5.minutes.from_now)
    nonce = SecureRandom.hex(32)
    verifier = SecureRandom.urlsafe_base64(48)
    cookies.encrypted[:pkbm_oidc_flow] = {value: {state: state, nonce: nonce, verifier: verifier}.to_json,
      httponly: true, same_site: :lax, secure: request.ssl?, expires: 5.minutes.from_now}
    redirect_to OidcClient.new.authorization(state: state, nonce: nonce, verifier: verifier), allow_other_host: true
  end
  def callback
    raw = cookies.encrypted[:pkbm_oidc_flow]
    cookies.delete(:pkbm_oidc_flow)
    raise OidcClient::Invalid unless raw
    flow = JSON.parse(raw)
    raise OidcClient::Invalid unless params[:state].is_a?(String) && ActiveSupport::SecurityUtils.secure_compare(params[:state], flow.fetch('state'))
    IdentityLoginFlow.transaction do
      login_flow = IdentityLoginFlow.lock.find_by!(state_digest: Digest::SHA256.hexdigest(flow.fetch('state')), used_at: nil)
      raise OidcClient::Invalid unless login_flow.expires_at > Time.current
      login_flow.update!(used_at: Time.current)
    end
    # Consume state server-side before token exchange to reject concurrent replay.
    client = OidcClient.new
    claims = client.redeem(code: params.require(:code), nonce: flow.fetch('nonce'), verifier: flow.fetch('verifier'))
    subject = IdentityExternalSubject.find_by!(issuer: OidcClient.new.issuer, protocol: 'oidc', subject: claims.fetch('sub'))
    identity = IdentityAccount.find(subject.identity_account_id)
    if identity.status == 'pending'
      activated = IdentityDirectory.new.user(subject.subject)
      raise OidcClient::Invalid unless activated['enabled'] && activated['emailVerified'] && activated.fetch('requiredActions', []).empty?
      identity.update!(status: 'active')
    end
    token = IdentitySessionStore.issue!(identity: identity, oidc_sid: claims['sid'])
    cookies.encrypted[:pkbm_logout_hint] = {value: client.logout_id_token, httponly: true, same_site: :lax, secure: request.ssl?, expires: 8.hours.from_now}
    cookies[:pkbm_identity_session] = {value: token, httponly: true, same_site: :lax, secure: request.ssl?, expires: 8.hours.from_now}
    response.headers['Cache-Control'] = 'no-store'
    redirect_to '/#identity', status: :see_other
  end
  def contexts
    session = IdentitySessionStore.resolve!(cookies[:pkbm_identity_session])
    links = IdentityMembershipLink.where(identity_account_id: session.identity_account_id)
    rows = links.filter_map do |link|
      member = OperationRecord.for('pkbm_memberships').find_by(id: link.membership_id, pkbm_id: link.pkbm_id, status: 'active')
      next unless member
      name = ActiveRecord::Base.connection.select_value("SELECT name FROM pkbms WHERE id=#{ActiveRecord::Base.connection.quote(link.pkbm_id)}")
      {pkbm_id: link.pkbm_id, membership_id: link.membership_id, name: name}
    end
    render json: {contexts: rows}
  end
  def context
    raise OidcClient::Invalid unless request.headers['Origin'] == ENV.fetch('PKBM_PUBLIC_BASE_URL')
    session = IdentitySessionStore.resolve!(cookies[:pkbm_identity_session])
    identity = IdentityAccount.find(session.identity_account_id)
    token = IdentitySessionStore.issue!(identity: identity, pkbm_id: params.require(:pkbm_id), membership_id: params.require(:membership_id), oidc_sid: session.oidc_sid)
    IdentitySessionStore.revoke!(cookies[:pkbm_identity_session])
    cookies[:pkbm_identity_session] = {value: token, httponly: true, same_site: :lax, secure: request.ssl?, expires: 8.hours.from_now}
    # Existing API/UI accepts the opaque server token. Do not mint legacy JWT.
    response.headers['Cache-Control'] = 'no-store'
    render json: {token: token, expires_in_seconds: 28_800}
  end
  def logout
    raise OidcClient::Invalid unless request.headers['Origin'] == ENV.fetch('PKBM_PUBLIC_BASE_URL')
    IdentitySessionStore.revoke!(cookies[:pkbm_identity_session])
    IdentitySessionStore.revoke!(request.headers['Authorization'].to_s.delete_prefix('Bearer '))
    cookies.delete(:pkbm_identity_session)
    options = {client_id: OidcClient.new.client_id, post_logout_redirect_uri: ENV.fetch('PKBM_PUBLIC_BASE_URL') + '/auth/login'}
    hint = cookies.encrypted[:pkbm_logout_hint]
    options[:id_token_hint] = hint if hint.present?
    cookies.delete(:pkbm_logout_hint)
    query = URI.encode_www_form(options)
    render json: {logout_url: OidcClient.new.issuer + '/protocol/openid-connect/logout?' + query,
      message: 'Sesi portal ditutup; selesaikan keluar pada layanan identitas.'}
  end
  def backchannel_logout
    claims = OidcClient.new.logout_claims(params.require(:logout_token))
    digest = Digest::SHA256.hexdigest('logout:' + claims.fetch('jti'))
    IdentitySession.transaction do
      IdentityLoginFlow.create!(id: SecureRandom.uuid, state_digest: digest, expires_at: Time.at(claims.fetch('exp')), used_at: Time.current)
      scope = IdentitySession.all
      if claims['sub'].present?
        subject = IdentityExternalSubject.find_by!(issuer: OidcClient.new.issuer, protocol: 'oidc', subject: claims['sub'])
        scope = scope.where(identity_account_id: subject.identity_account_id)
      end
      scope = scope.where(oidc_sid: claims['sid']) if claims['sid'].present?
      scope.where(revoked_at: nil).update_all(revoked_at: Time.current)
    end
    head :ok
  rescue ActiveRecord::RecordNotUnique
    render json: {error: 'Logout replay'}, status: :bad_request
  end
  private
  def enabled!
    response.headers['Cache-Control'] = 'no-store'
    response.headers['Referrer-Policy'] = 'no-referrer'
    render json: {error: 'Login bersama sedang disiapkan'}, status: :service_unavailable unless ENV['PKBM_SSO_ENABLED'] == 'true'
  end
end
