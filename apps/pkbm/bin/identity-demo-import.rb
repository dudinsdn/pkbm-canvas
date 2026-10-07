# Only explicitly reviewed DEMO fixtures exported from local tenant metadata.
rows = JSON.parse(File.read(ENV.fetch('PKBM_IDENTITY_MAPPING_FILE')))
raise 'Expected six demo profiles' unless rows.length == 6
IdentityAccount.transaction do
  rows.each do |row|
    tenant = ActiveRecord::Base.connection.select_one("SELECT local_code FROM pkbms WHERE id=#{ActiveRecord::Base.connection.quote(row.fetch('pkbm_id'))}")
    raise 'Tenant mismatch' unless tenant && tenant['local_code'] == row.fetch('tenant_code') && %w[DEMO-A DEMO-B].include?(tenant['local_code'])
    membership = OperationRecord.for('pkbm_memberships').find_by!(id: row.fetch('membership_id'), pkbm_id: row.fetch('pkbm_id'), person_id: row.fetch('person_id'), status: 'active')
    actor = OperationRecord.for('role_assignments').find_by!(pkbm_id: membership.pkbm_id, role: 'pengelola').membership_id
    identity = IdentityRegistry.new(actor_membership_id: actor).create_for_membership!(pkbm_id: membership.pkbm_id, membership_id: membership.id, reason: 'Migrasi fixture DEMO eksplisit berdasarkan ID membership, bukan email')
    subject = IdentityExternalSubject.find_or_initialize_by(issuer: 'http://127.0.0.1:8082/realms/pkbm', protocol: 'oidc', subject: row.fetch('idp_subject'))
    raise 'Subject already owned by another identity' if subject.persisted? && subject.identity_account_id != identity.id
    unless subject.persisted?
      subject.assign_attributes(id: SecureRandom.uuid, identity_account_id: identity.id, verified_at: Time.current)
      subject.save!
      IdentityMigrationEvent.create!(id: SecureRandom.uuid, identity_account_id: identity.id, actor_membership_id: actor, event_type: 'subject_linked', reason: 'Subject diperoleh dari API admin IdP dengan marker membership yang cocok', reference_id: subject.id)
    end
    identity.update!(status: 'active')
  end
end
puts 'Six demo profile identities and OIDC subjects linked. Canvas bindings unchanged.'
