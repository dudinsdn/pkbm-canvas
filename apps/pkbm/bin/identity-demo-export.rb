# Metadata only; export existing tenant/profile binding without credentials.
rows = []
OperationRecord.for('pkbm_memberships').where(status: 'active').find_each do |member|
  tenant = ActiveRecord::Base.connection.select_one("SELECT id,local_code FROM pkbms WHERE id=#{ActiveRecord::Base.connection.quote(member.pkbm_id)}")
  next unless %w[DEMO-A DEMO-B].include?(tenant['local_code'])
  person = OperationRecord.for('people').find(member.person_id)
  roles = OperationRecord.for('role_assignments').where(pkbm_id: member.pkbm_id, membership_id: member.id).pluck(:role)
  next unless roles.length == 1 && %w[pengelola tutor warga_belajar].include?(roles.first)
  instance = CanvasInstance.find_by(pkbm_id: member.pkbm_id)
  binding = instance && CanvasBinding.find_by(canvas_instance_id: instance.id, object_kind: 'user', local_key: person.id)
  rows << {pkbm_id: member.pkbm_id, membership_id: member.id, person_id: person.id,
    tenant_code: tenant['local_code'], role: roles.first, name: person.name,
    canvas_user_id: binding&.remote_id}
end
puts JSON.generate(rows)
