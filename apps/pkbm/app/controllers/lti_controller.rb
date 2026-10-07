require "openssl"
require "base64"
require "cgi"
require "digest"
require "uri"
class LtiController < ActionController::API
  include ActionController::Cookies
  def launch
    instance = CanvasInstance.find_by!(consumer_key: params.require(:oauth_consumer_key), enabled: true)
    values = request.request_parameters.to_h
    raise ArgumentError unless request.query_parameters.empty? && request.media_type == "application/x-www-form-urlencoded"
    raise ArgumentError unless values.values.all? { |v| v.is_a?(String) }
    required = %w[oauth_signature oauth_signature_method oauth_nonce oauth_timestamp oauth_version lti_message_type lti_version custom_canvas_user_id custom_canvas_course_id]
    raise ArgumentError unless required.all? { |key| values[key].present? }
    raise ArgumentError unless values['oauth_signature_method'] == 'HMAC-SHA1' && values['oauth_version'] == '1.0' && values['lti_version'] == 'LTI-1p0' && values['lti_message_type'] == 'basic-lti-launch-request'
    raise ArgumentError unless values['oauth_timestamp'].match?(/\A\d+\z/) && (Time.now.to_i - values['oauth_timestamp'].to_i).abs <= 300
    raise ArgumentError if values['oauth_nonce'].bytesize > 512 || values['oauth_token'].present?
    percent = ->(value) { URI.encode_www_form_component(value.to_s).gsub('+','%20').gsub('%7E','~').gsub('*','%2A') }
    normalized = values.except('oauth_signature').map { |k,v| [percent.call(k),percent.call(v)] }.sort.map { |k,v| "#{k}=#{v}" }.join('&')
    canonical = "#{ENV.fetch('PKBM_PUBLIC_BASE_URL','http://127.0.0.1:3000')}/lti/launch"
    base = ['POST',percent.call(canonical),percent.call(normalized)].join('&')
    key = percent.call(instance.credentials.fetch('lti_secret')) + '&'
    expected = Base64.strict_encode64(OpenSSL::HMAC.digest('sha1',key,base))
    raise ArgumentError unless ActiveSupport::SecurityUtils.secure_compare(expected,values['oauth_signature'])
    course = CanvasBinding.find_by!(pkbm_id: instance.pkbm_id, canvas_instance_id: instance.id, object_kind: 'course', remote_id: values['custom_canvas_course_id'])
    user = CanvasBinding.find_by!(pkbm_id: instance.pkbm_id, canvas_instance_id: instance.id, object_kind: 'user', remote_id: values['custom_canvas_user_id'])
    member = OperationRecord.for('pkbm_memberships').find_by!(pkbm_id: instance.pkbm_id, person_id: user.local_key, status: 'active')
    scope = OperationScope.new(instance.pkbm_id,member.id)
    raise ArgumentError unless scope.records('deliveries').where(id: course.local_key).exists?
    code = SecureRandom.hex(32)
    ActiveRecord::Base.transaction do
      LtiNonce.create!(id: SecureRandom.uuid, canvas_instance_id: instance.id, nonce_digest: Digest::SHA256.hexdigest(values['oauth_nonce']), expires_at: 10.minutes.from_now)
      LtiLaunchCode.create!(id: SecureRandom.uuid, pkbm_id: instance.pkbm_id, membership_id: member.id, code_digest: Digest::SHA256.hexdigest(code), expires_at: 60.seconds.from_now)
    end
    response.headers['Cache-Control']='no-store'
    response.headers['Referrer-Policy']='no-referrer'
    redirect_to "#{ENV.fetch('PKBM_PUBLIC_BASE_URL','http://127.0.0.1:3000')}/#lti_code=#{code}", allow_other_host: true, status: :see_other
  rescue ArgumentError, ActiveRecord::RecordNotFound, ActiveRecord::RecordNotUnique, ActionController::ParameterMissing
    render json: {error:'Launch LTI tidak sah, kedaluwarsa, replay, atau di luar lingkup'}, status: :unauthorized
  end

  def exchange
    token = nil
    LtiLaunchCode.transaction do
      launch = LtiLaunchCode.lock.find_by!(code_digest: Digest::SHA256.hexdigest(params.require(:code).to_s), used_at: nil)
      raise ArgumentError unless launch.expires_at > Time.current
      member = OperationRecord.for('pkbm_memberships').find_by!(id: launch.membership_id, pkbm_id: launch.pkbm_id, status: 'active')
      if ENV['PKBM_SSO_ENABLED'] == 'true'
        session = IdentitySessionStore.resolve!(cookies[:pkbm_identity_session])
        link = IdentityMembershipLink.find_by!(membership_id: member.id, identity_account_id: session.identity_account_id)
        identity = IdentityAccount.find(link.identity_account_id)
        token = IdentitySessionStore.issue!(identity: identity, pkbm_id: member.pkbm_id, membership_id: member.id, oidc_sid: session.oidc_sid)
        IdentitySessionStore.revoke!(cookies[:pkbm_identity_session])
        cookies[:pkbm_identity_session] = {value: token, httponly: true, same_site: :lax, secure: request.ssl?, expires: 8.hours.from_now}
      else
        token = Rails.application.message_verifier('pkbm_operations').generate({'pkbm_id'=>member.pkbm_id,'membership_id'=>member.id},expires_in:8.hours,purpose:'pkbm_operations')
      end
      launch.update!(used_at: Time.current)
    end
    response.headers['Cache-Control']='no-store'
    render json: {token:token,expires_in_seconds:28_800}
  rescue IdentitySessionStore::Unauthorized, ArgumentError, ActiveRecord::RecordNotFound, ActionController::ParameterMissing
    render json:{error:'Kode launch tidak tersedia atau kedaluwarsa'},status: :unauthorized
  end
end
