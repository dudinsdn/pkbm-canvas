# Run with rails runner. All fixtures are rolled back; no Canvas API calls.
require 'json'
passed = []
check = ->(name, &block) { raise "FAILED: #{name}" unless block.call; passed << name }
reject = ->(name, klass, &block) do
  caught = false
  begin
    ActiveRecord::Base.transaction(requires_new: true) { block.call }
  rescue klass
    caught = true
  end
  check.call(name) { caught }
end
before = [IdentityAccount, IdentityMembershipLink, IdentitySession, IdentityMigrationEvent].map(&:count)
ActiveRecord::Base.transaction do
  tenants = ActiveRecord::Base.connection.select_values('SELECT id FROM pkbms ORDER BY local_code LIMIT 2')
  raise 'Need two existing PKBM fixtures' unless tenants.length == 2
  members = OperationRecord.for('pkbm_memberships')
  roles = OperationRecord.for('role_assignments')
  managers = tenants.map { |t| roles.find_by!(pkbm_id: t, role: 'pengelola').membership_id }
  fixture_email = "validation-#{SecureRandom.hex(8)}@pkbm.local"
  learners = tenants.map do |tenant|
    person = OperationRecord.for('people').create!(id: SecureRandom.uuid, pkbm_id: tenant, name: 'Same fixture name', email: fixture_email, password_digest: LocalCredentials.digest(SecureRandom.hex(32)))
    member = members.create!(id: SecureRandom.uuid, pkbm_id: tenant, person_id: person.id, status: 'active')
    roles.create!(id: SecureRandom.uuid, pkbm_id: tenant, membership_id: member.id, role: 'warga_belajar')
    member.id
  end
  registry = IdentityRegistry.new(actor_membership_id: managers[0])
  one = registry.create_for_membership!(pkbm_id: tenants[0], membership_id: learners[0], reason: 'Isolated validation fixture')
  check.call('identity starts pending') { one.status == 'pending' }
  again = registry.create_for_membership!(pkbm_id: tenants[0], membership_id: learners[0], reason: 'Retry')
  check.call('retry reuses identity') { again.id == one.id }
  reject.call('other tenant manager rejected', ActiveRecord::RecordNotFound) { registry.create_for_membership!(pkbm_id: tenants[1], membership_id: learners[1], reason: 'Denied') }
  reject.call('learner cannot provision', IdentityRegistry::Forbidden) { IdentityRegistry.new(actor_membership_id: learners[0]).create_for_membership!(pkbm_id: tenants[0], membership_id: learners[0], reason: 'Denied') }
  two = IdentityRegistry.new(actor_membership_id: managers[1]).create_for_membership!(pkbm_id: tenants[1], membership_id: learners[1], reason: 'Separate identity')
  check.call('tenant profiles not merged by email') { one.id != two.id }
  person = OperationRecord.for('people').create!(id: SecureRandom.uuid, pkbm_id: tenants[1], name: 'Explicit shared identity', email: "shared-#{SecureRandom.hex(8)}@pkbm.local", password_digest: LocalCredentials.digest(SecureRandom.hex(32)))
  shared_member = members.create!(id: SecureRandom.uuid, pkbm_id: tenants[1], person_id: person.id, status: 'active')
  IdentityRegistry.new(actor_membership_id: managers[1]).link_membership!(identity: one, pkbm_id: tenants[1], membership_id: shared_member.id, reason: 'Explicit reviewed same person across PKBM validation')
  one.update!(status: 'active')
  shared_token = IdentitySessionStore.issue!(identity: one, pkbm_id: tenants[1], membership_id: shared_member.id)
  check.call('one identity uses second tenant context explicitly') { IdentitySessionStore.resolve!(shared_token).pkbm_id == tenants[1] }
  one.update!(status: 'pending')

  reject.call('membership conflict rejected', IdentityRegistry::Conflict) { registry.link_membership!(identity: two, pkbm_id: tenants[0], membership_id: learners[0], reason: 'Conflict') }
  reject.call('pending identity cannot issue session', IdentitySessionStore::Unauthorized) { IdentitySessionStore.issue!(identity: one) }
  one.update!(status: 'active')
  token = IdentitySessionStore.issue!(identity: one, pkbm_id: tenants[0], membership_id: learners[0])
  session = IdentitySessionStore.resolve!(token)
  check.call('active identity resolves own membership') { session.membership_id == learners[0] }
  check.call('raw token not stored') { session.token_digest != token && session.token_digest == Digest::SHA256.hexdigest(token) }
  reject.call('foreign membership session rejected', IdentitySessionStore::Unauthorized) { IdentitySessionStore.issue!(identity: one, pkbm_id: tenants[1], membership_id: learners[1]) }
  members.find(learners[0]).update!(status: 'inactive')
  reject.call('inactive membership revokes effective access', IdentitySessionStore::Unauthorized) { IdentitySessionStore.resolve!(token) }
  members.find(learners[0]).update!(status: 'active')
  one.update!(session_version: 2)
  reject.call('session version revocation', IdentitySessionStore::Unauthorized) { IdentitySessionStore.resolve!(token) }
  token = IdentitySessionStore.issue!(identity: one)
  IdentitySessionStore.revoke!(token)
  reject.call('explicit session revocation', IdentitySessionStore::Unauthorized) { IdentitySessionStore.resolve!(token) }
  token = IdentitySessionStore.issue!(identity: one)
  IdentitySession.where(identity_account_id: one.id, revoked_at: nil).update_all(expires_at: Time.current - 1.second, created_at: Time.current - 1.hour)
  reject.call('expired session rejected', IdentitySessionStore::Unauthorized) { IdentitySessionStore.resolve!(token) }
  token = IdentitySessionStore.issue!(identity: one)
  one.update!(status: 'disabled')
  reject.call('disabled identity rejected', IdentitySessionStore::Unauthorized) { IdentitySessionStore.resolve!(token) }
  reject.call('malformed token rejected', IdentitySessionStore::Unauthorized) { IdentitySessionStore.resolve!('invalid') }
  subject = {issuer: 'urn:test:pkbm', protocol: 'saml', subject: 'stable-test-subject', verified_at: Time.current}
  IdentityExternalSubject.create!(subject.merge(id: SecureRandom.uuid, identity_account_id: one.id))
  reject.call('duplicate external subject rejected', ActiveRecord::RecordNotUnique) { IdentityExternalSubject.create!(subject.merge(id: SecureRandom.uuid, identity_account_id: two.id)) }
  unlinked = IdentityAccount.create!(id: SecureRandom.uuid)
  fixture_person = OperationRecord.for('people').create!(id: SecureRandom.uuid, pkbm_id: tenants[0], name: 'Unlinked FK fixture', email: "fk-#{SecureRandom.hex(8)}@pkbm.local", password_digest: LocalCredentials.digest(SecureRandom.hex(32)))
  unlinked_member = members.create!(id: SecureRandom.uuid, pkbm_id: tenants[0], person_id: fixture_person.id, status: 'active')
  reject.call('tenant membership FK rejects mismatch', ActiveRecord::InvalidForeignKey) { IdentityMembershipLink.create!(id: SecureRandom.uuid, identity_account_id: unlinked.id, pkbm_id: tenants[1], membership_id: unlinked_member.id) }
  link = {deployment_key: 'validation-only', root_account_id: 1, remote_user_id: '999901', authentication_provider_id: '999', federated_identifier: 'fixture-one'}
  CanvasIdentityLink.create!(link.merge(id: SecureRandom.uuid, identity_account_id: one.id))
  reject.call('duplicate Canvas user rejected', ActiveRecord::RecordNotUnique) { CanvasIdentityLink.create!(link.merge(id: SecureRandom.uuid, identity_account_id: two.id, federated_identifier: 'fixture-two')) }
  reject.call('ready Canvas link needs verification', ActiveRecord::StatementInvalid) { CanvasIdentityLink.create!(link.merge(id: SecureRandom.uuid, identity_account_id: two.id, remote_user_id: '999902', federated_identifier: 'fixture-two', status: 'ready')) }
  event = IdentityMigrationEvent.first!
  reject.call('audit update rejected', ActiveRecord::StatementInvalid) { event.update!(reason: 'tampered') }
  reject.call('audit delete rejected', ActiveRecord::StatementInvalid) { event.destroy! }
  raise ActiveRecord::Rollback
end
check.call('fixture transaction rolled back') { before == [IdentityAccount, IdentityMembershipLink, IdentitySession, IdentityMigrationEvent].map(&:count) }
puts JSON.pretty_generate({stage: '5A identity foundation', passed: passed.length, failed: 0, checks: passed, fixtures_rolled_back: true, canvas_calls: 0})
