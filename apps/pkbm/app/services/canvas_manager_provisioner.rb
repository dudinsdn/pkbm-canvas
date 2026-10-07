# Explicit operator action: create/reuse a federated user, then grant only the
# PKBM subaccount. No native password and no root-account administrator grant.
class CanvasManagerProvisioner
  class Conflict < StandardError; end
  def initialize(instance:, provider_id:)
    @instance, @provider_id = instance, provider_id.to_s
    @api = CanvasApi.new(instance)
  end

  def provision!(membership_id:)
    member = OperationRecord.for('pkbm_memberships').find_by!(id: membership_id, pkbm_id: @instance.pkbm_id, status: 'active')
    raise Conflict, 'Peran pengelola diperlukan' unless OperationRecord.for('role_assignments').exists?(pkbm_id: member.pkbm_id, membership_id: member.id, role: 'pengelola')
    identity = IdentityAccount.find(IdentityMembershipLink.find_by!(membership_id: member.id, pkbm_id: member.pkbm_id).identity_account_id)
    identity.with_lock do
      raise Conflict, 'Identity tidak aktif' unless identity.status == 'active'
      account = CanvasBinding.find_by!(pkbm_id: member.pkbm_id, canvas_instance_id: @instance.id, object_kind: 'account', local_key: member.pkbm_id)
      remote = @api.request('GET', "/api/v1/accounts/#{account.remote_id}")
      raise Conflict, 'Subaccount PKBM tidak cocok' unless remote['parent_account_id'].to_s == @instance.root_account_id.to_s && remote['id'].to_s == account.remote_id && remote['sis_account_id'] == "pkbm-#{member.pkbm_id}-account-#{member.pkbm_id}"
      person = OperationRecord.for('people').find_by!(id: member.person_id, pkbm_id: member.pkbm_id)
      subject = IdentityExternalSubject.find_by!(identity_account_id: identity.id, issuer: ENV.fetch('PKBM_OIDC_ISSUER'), protocol: 'oidc')
      binding = CanvasBinding.find_by(pkbm_id: member.pkbm_id, canvas_instance_id: @instance.id, object_kind: 'user', local_key: person.id)
      global = CanvasIdentityLink.find_by(identity_account_id: identity.id, deployment_key: 'pkbm-canvas-local', root_account_id: @instance.root_account_id)
      raise Conflict, 'Binding berbeda dari identity' if binding && global && binding.remote_id != global.remote_user_id
      sis_id = "pkbm-identity-#{identity.id}"
      user = if binding || global
        @api.request('GET', "/api/v1/users/#{binding&.remote_id || global.remote_user_id}")
      else
        @api.request('GET', "/api/v1/users/sis_user_id:#{sis_id}", nil, allow_missing: true)
      end
      unless user
        user = @api.request('POST', "/api/v1/accounts/#{@instance.root_account_id}/users", {
          'user'=>{'name'=>person.name, 'skip_registration'=>true},
          'pseudonym'=>{'unique_id'=>subject.subject, 'sis_user_id'=>sis_id,
            'authentication_provider_id'=>@provider_id, 'send_confirmation'=>false}})
      end
      user_id = user.fetch('id').to_s
      unless binding
        CanvasBinding.create!(id: SecureRandom.uuid, pkbm_id: member.pkbm_id, canvas_instance_id: @instance.id,
          object_kind: 'user', local_key: person.id, remote_id: user_id, remote_context: '',
          last_payload_checksum: Digest::SHA256.hexdigest(JSON.generate({'name'=>person.name})), last_remote_snapshot: {'name'=>user['name']})
      end
      link = CanvasIdentityProvisioner.new(instance: @instance, provider_id: @provider_id, deployment_key: 'pkbm-canvas-local').link!(membership_id: member.id, actor_membership_id: member.id)
      raise Conflict, 'User federasi berbeda' unless link.remote_user_id == user_id
      root_admins = @api.list("/api/v1/accounts/#{@instance.root_account_id}/admins?user_id[]=#{user_id}")
      raise Conflict, 'Pengelola memiliki hak root; perlu telaah' unless root_admins.empty?
      admins = @api.list("/api/v1/accounts/#{account.remote_id}/admins?user_id[]=#{user_id}")
      matching = admins.select { |row| row.dig('user','id').to_s == user_id && row['role'] == 'AccountAdmin' }
      raise Conflict, 'Hak pengelola berbeda; perlu telaah' if admins.any? && matching.length != 1
      @api.request('POST', "/api/v1/accounts/#{account.remote_id}/admins", {'user_id'=>user_id, 'send_confirmation'=>false}) if matching.empty?
      verified = @api.list("/api/v1/accounts/#{account.remote_id}/admins?user_id[]=#{user_id}").select { |row| row.dig('user','id').to_s == user_id && row['role'] == 'AccountAdmin' }
      raise Conflict, 'Hak Canvas belum siap' unless verified.length == 1
      management = CanvasManagementLink.find_or_initialize_by(canvas_instance_id: @instance.id, membership_id: member.id)
      management.assign_attributes(id: management.id || SecureRandom.uuid, pkbm_id: member.pkbm_id,
        identity_account_id: identity.id, remote_account_id: account.remote_id, remote_user_id: user_id,
        remote_role_id: verified.first.fetch('role_id').to_s, status: 'ready', verified_at: Time.current)
      management.save!
      management
    end
  end
end
