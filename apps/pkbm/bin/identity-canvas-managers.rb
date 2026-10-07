# Explicit local provisioning using an approved temporary operational API token.
# Token is kept in memory and is never saved in CanvasInstance credentials.
token = JSON.parse(File.read('/tmp/pkbm-manager-token.json')).fetch('token')
rows = []
demo_ids = ActiveRecord::Base.connection.select_values("SELECT id FROM pkbms WHERE local_code IN ('DEMO-A','DEMO-B')")
CanvasInstance.where(enabled: true, pkbm_id: demo_ids).find_each do |instance|
  instance.credentials = instance.credentials.merge('access_token'=>token)
  providers = CanvasApi.new(instance).list("/api/v1/accounts/#{instance.root_account_id}/authentication_providers").select { |row| row['auth_type'] == 'openid_connect' && row['client_id'] == 'pkbm-canvas' }
  raise 'Provider OIDC PKBM harus tunggal' unless providers.length == 1
  provisioner = CanvasManagerProvisioner.new(instance: instance, provider_id: providers.first.fetch('id'))
  OperationRecord.for('role_assignments').where(pkbm_id: instance.pkbm_id, role: 'pengelola').find_each do |assignment|
    result = provisioner.provision!(membership_id: assignment.membership_id)
    rows << result.attributes.slice('pkbm_id','membership_id','remote_account_id','remote_user_id','status')
  end
end
puts JSON.generate(provisioned: rows)
