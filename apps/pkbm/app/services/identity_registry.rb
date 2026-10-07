# Internal provisioning primitive. Never exposed as an unauthenticated account
# claim endpoint. Federation callbacks must validate assertions before use.
class IdentityRegistry
  class Conflict < StandardError; end
  class Forbidden < StandardError; end

  def initialize(actor_membership_id:)
    @actor_id = actor_membership_id
  end

  def create_for_membership!(pkbm_id:, membership_id:, reason:)
    ActiveRecord::Base.transaction do
      membership = authorized_membership!(pkbm_id, membership_id)
      existing = IdentityMembershipLink.find_by(membership_id: membership.id)
      return IdentityAccount.find(existing.identity_account_id) if existing
      identity = IdentityAccount.create!(id: SecureRandom.uuid)
      link_membership!(identity: identity, pkbm_id: pkbm_id, membership_id: membership_id, reason: reason)
      audit!(identity, 'identity_created', reason, identity.id)
      identity
    end
  end

  # Linking a second tenant requires an explicit operator-reviewed identity,
  # rather than an email/name match. Each target tenant authorizes its own link.
  def link_membership!(identity:, pkbm_id:, membership_id:, reason:)
    ActiveRecord::Base.transaction do
      identity.lock!
      raise Conflict, 'Identitas dinonaktifkan' if identity.status == 'disabled'
      membership = authorized_membership!(pkbm_id, membership_id)
      existing = IdentityMembershipLink.find_by(membership_id: membership.id)
      if existing
        raise Conflict, 'Membership sudah terhubung ke identitas lain' unless existing.identity_account_id == identity.id
        return existing
      end
      if IdentityMembershipLink.exists?(identity_account_id: identity.id, pkbm_id: pkbm_id)
        raise Conflict, 'Identitas sudah mempunyai profil pada PKBM ini'
      end
      link = IdentityMembershipLink.create!(id: SecureRandom.uuid, identity_account_id: identity.id,
        pkbm_id: pkbm_id, membership_id: membership.id)
      audit!(identity, 'membership_linked', reason, link.id)
      link
    end
  end

  private

  def authorized_membership!(pkbm_id, membership_id)
    memberships = OperationRecord.for('pkbm_memberships')
    actor = memberships.lock.find_by!(id: @actor_id, pkbm_id: pkbm_id, status: 'active')
    unless OperationRecord.for('role_assignments').exists?(pkbm_id: pkbm_id, membership_id: actor.id, role: 'pengelola')
      raise Forbidden, 'Pemetaan identitas memerlukan pengelola PKBM'
    end
    memberships.lock.find_by!(id: membership_id, pkbm_id: pkbm_id, status: 'active')
  end

  def audit!(identity, event_type, reason, reference_id)
    raise ArgumentError, 'Alasan telaah wajib diisi' if reason.to_s.strip.empty?
    IdentityMigrationEvent.create!(id: SecureRandom.uuid, identity_account_id: identity.id,
      actor_membership_id: @actor_id, event_type: event_type, reason: reason, reference_id: reference_id)
  end
end
