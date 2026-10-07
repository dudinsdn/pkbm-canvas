# A temporary API credential must be supplied securely by the operator.
# Run after approved token setup; no direct Canvas database writes.
provider_params = JSON.parse(File.read('/tmp/pkbm-canvas-provider.json'))
instances = CanvasInstance.where(enabled: true).to_a
raise 'No configured Canvas instance' if instances.empty?
token = JSON.parse(File.read('/tmp/pkbm-stage5a-token.json')).fetch('token')
instances.each { |instance| instance.credentials = instance.credentials.merge('access_token' => token) }
first = instances.first
api = CanvasApi.new(first)
providers = api.list("/api/v1/accounts/#{first.root_account_id}/authentication_providers")
existing = providers.select { |provider| provider['auth_type'] == 'openid_connect' && provider['client_id'] == provider_params.fetch('client_id') }
raise 'Conflicting OIDC provider' if existing.length > 1
provider = existing.first ? api.request('PUT', "/api/v1/accounts/#{first.root_account_id}/authentication_providers/#{existing.first.fetch('id')}", provider_params) : api.request('POST', "/api/v1/accounts/#{first.root_account_id}/authentication_providers", provider_params)
rows = []
instances.each do |instance|
  provisioner = CanvasIdentityProvisioner.new(instance: instance, provider_id: provider.fetch('id'), deployment_key: 'pkbm-canvas-local')
  actor = OperationRecord.for('role_assignments').find_by!(pkbm_id: instance.pkbm_id, role: 'pengelola').membership_id
  OperationRecord.for('pkbm_memberships').where(pkbm_id: instance.pkbm_id, status: 'active').find_each do |member|
    next unless CanvasBinding.exists?(canvas_instance_id: instance.id, object_kind: 'user', local_key: member.person_id)
    link = provisioner.link!(membership_id: member.id, actor_membership_id: actor)
    rows << {membership_id: member.id, canvas_user_id: link.remote_user_id}
  end
end
puts JSON.generate(provider_id: provider.fetch('id'), linked: rows)
