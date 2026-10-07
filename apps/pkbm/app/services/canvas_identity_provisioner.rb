# Adds a federated login to an existing bound user; does not create/merge users.
class CanvasIdentityProvisioner
  class Conflict < StandardError; end
  def initialize(instance:, provider_id:, deployment_key:)
    @instance, @provider_id, @deployment_key = instance, provider_id.to_s, deployment_key
    @api = CanvasApi.new(instance)
  end
  def link!(membership_id:, actor_membership_id:)
    membership = OperationRecord.for('pkbm_memberships').find_by!(id: membership_id, pkbm_id: @instance.pkbm_id, status: 'active')
    actor = OperationRecord.for('pkbm_memberships').find_by!(id: actor_membership_id, pkbm_id: @instance.pkbm_id, status: 'active')
    raise Conflict unless OperationRecord.for('role_assignments').exists?(pkbm_id: actor.pkbm_id, membership_id: actor.id, role: 'pengelola')
    identity = IdentityAccount.find(IdentityMembershipLink.find_by!(membership_id: membership.id).identity_account_id)
    identity.with_lock do
      raise Conflict unless identity.status == 'active'
      subject = IdentityExternalSubject.find_by!(identity_account_id: identity.id, issuer: ENV.fetch('PKBM_OIDC_ISSUER'), protocol: 'oidc')
      binding = CanvasBinding.find_by!(canvas_instance_id: @instance.id, object_kind: 'user', local_key: membership.person_id)
      link = CanvasIdentityLink.find_or_initialize_by(identity_account_id: identity.id, deployment_key: @deployment_key, root_account_id: @instance.root_account_id)
      if link.persisted? && (link.remote_user_id != binding.remote_id || link.federated_identifier != subject.subject || link.authentication_provider_id != @provider_id)
        raise Conflict, 'Mapping identity Canvas berbeda dari binding'
      end
      existing = @api.list("/api/v1/users/#{binding.remote_id}/logins").select { |login| login['account_id'].to_s == @instance.root_account_id.to_s && login['unique_id'] == subject.subject && login['authentication_provider_id'].to_s == @provider_id }
      raise Conflict if existing.length > 1 || existing.any? { |login| login['user_id'].to_s != binding.remote_id }
      unless existing.any?
        @api.request('POST', "/api/v1/accounts/#{@instance.root_account_id}/logins", {'user'=>{'id'=>binding.remote_id}, 'login'=>{'unique_id'=>subject.subject, 'authentication_provider_id'=>@provider_id}})
      end
      # Never ready merely because a POST succeeded. Re-read the remote mapping.
      remote = @api.list("/api/v1/users/#{binding.remote_id}/logins").select { |login| login['account_id'].to_s == @instance.root_account_id.to_s && login['unique_id'] == subject.subject && login['authentication_provider_id'].to_s == @provider_id }
      raise Conflict unless remote.length == 1
      link.assign_attributes(id: link.id || SecureRandom.uuid, remote_user_id: binding.remote_id, authentication_provider_id: @provider_id, federated_identifier: subject.subject, status: 'ready', verified_at: Time.current)
      fresh = link.new_record?; link.save!
      if fresh
        IdentityMigrationEvent.create!(id: SecureRandom.uuid, identity_account_id: identity.id, actor_membership_id: actor.id, event_type: 'canvas_linked', reason: 'Login federasi dipasang melalui API pada user Canvas terikat; histori dipertahankan', reference_id: link.id)
      end
      link
    end
  end
end
