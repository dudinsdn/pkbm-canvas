# Retire only profiles created by identity-activation-api.py; retain their audit.
directory = IdentityDirectory.new
count = 0
OperationRecord.for('people').where(name: 'Local activation validation').find_each do |person|
  next unless person.email.to_s.match?(/\Avalidation-[0-9a-f]{12}@pkbm\.local\z/)
  member = OperationRecord.for('pkbm_memberships').find_by!(pkbm_id: person.pkbm_id, person_id: person.id)
  link = IdentityMembershipLink.find_by!(membership_id: member.id, pkbm_id: person.pkbm_id)
  identity = IdentityAccount.find(link.identity_account_id)
  next if identity.status == 'disabled'
  subject = directory.create(username: person.email.split('@').first, email: person.email, name: person.name, membership_id: member.id)
  directory.disable(subject)
  identity.with_lock do
    identity.update!(status: 'disabled', session_version: identity.session_version + 1)
    IdentitySession.where(identity_account_id: identity.id, revoked_at: nil).update_all(revoked_at: Time.current)
    member.update!(status: 'inactive')
    actor = OperationRecord.for('role_assignments').find_by!(pkbm_id: person.pkbm_id, role: 'pengelola').membership_id
    IdentityMigrationEvent.create!(id: SecureRandom.uuid, identity_account_id: identity.id, actor_membership_id: actor,
      event_type: 'identity_disabled', reason: 'Retire named local activation validation fixture; audit preserved', reference_id: identity.id)
  end
  count += 1
end
puts JSON.generate(retired_test_profiles: count, audit_preserved: true, real_accounts_changed: false)
