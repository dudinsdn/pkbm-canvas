require 'digest'
require 'securerandom'

# Used only after verified federation has resolved an active global identity.
# The opaque token is returned once; only its digest is stored in the database.
class IdentitySessionStore
  LIFETIME = 8.hours
  class Unauthorized < StandardError; end

  def self.issue!(identity:, pkbm_id: nil, membership_id: nil, oidc_sid: nil)
    identity.with_lock do
      raise Unauthorized unless identity.status == 'active'
      context!(identity, pkbm_id, membership_id)
      token = SecureRandom.hex(32)
      IdentitySession.create!(id: SecureRandom.uuid, identity_account_id: identity.id,
        token_digest: Digest::SHA256.hexdigest(token), session_version: identity.session_version,
        pkbm_id: pkbm_id, membership_id: membership_id, oidc_sid: oidc_sid, expires_at: Time.current + LIFETIME)
      token
    end
  end

  def self.resolve!(token)
    raise Unauthorized unless token.to_s.match?(/\A[a-f0-9]{64}\z/)
    session = IdentitySession.find_by(token_digest: Digest::SHA256.hexdigest(token))
    raise Unauthorized unless session && !session.revoked_at && session.expires_at > Time.current
    identity = IdentityAccount.find(session.identity_account_id)
    raise Unauthorized unless identity.status == 'active' && identity.session_version == session.session_version
    context!(identity, session.pkbm_id, session.membership_id)
    session
  end

  def self.revoke!(token)
    return unless token.to_s.match?(/\A[a-f0-9]{64}\z/)
    IdentitySession.where(token_digest: Digest::SHA256.hexdigest(token), revoked_at: nil)
      .update_all(revoked_at: Time.current)
  end

  def self.context!(identity, pkbm_id, membership_id)
    return if pkbm_id.nil? && membership_id.nil?
    raise Unauthorized if pkbm_id.nil? || membership_id.nil?
    unless IdentityMembershipLink.exists?(identity_account_id: identity.id, pkbm_id: pkbm_id, membership_id: membership_id) &&
        OperationRecord.for('pkbm_memberships').exists?(id: membership_id, pkbm_id: pkbm_id, status: 'active')
      raise Unauthorized
    end
  end
  private_class_method :context!
end
