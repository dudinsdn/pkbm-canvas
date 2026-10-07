class IdentityInvitationsController < OperationsController
  rescue_from IdentityDirectory::Unavailable, IdentityRegistry::Conflict do |error|
    render json: {error: error.message}, status: :conflict
  end
  def create
    raise OperationWriter::Forbidden, 'Aktivasi akun dikelola pengelola PKBM' unless @scope.manager?
    member = @scope.base('pkbm_memberships').find_by!(id: params.require(:membership_id), status: 'active')
    raise OperationWriter::Invalid, 'Anggota belum memiliki peran' unless @scope.base('role_assignments').exists?(membership_id: member.id)
    person = @scope.base('people').find(member.person_id)
    username = params.require(:username).to_s.strip
    raise OperationWriter::Invalid, 'Username gunakan 3–80 huruf, angka, titik atau tanda hubung' unless username.match?(/\A[a-z0-9][a-z0-9.-]{2,79}\z/)
    raise OperationWriter::Invalid, 'Email anggota wajib tersedia' unless person.email.to_s.match?(/\A[^\s@]+@[^\s@]+\.[^\s@]+\z/)
    registry = IdentityRegistry.new(actor_membership_id: @scope.membership_id)
    identity = registry.create_for_membership!(pkbm_id: @scope.pkbm_id, membership_id: member.id, reason: 'Pengelola mengundang akun terpusat')
    identity.with_lock do
      subject = IdentityExternalSubject.find_by(identity_account_id: identity.id, issuer: ENV.fetch('PKBM_OIDC_ISSUER'), protocol: 'oidc')
      raise OperationWriter::Invalid, 'Undangan hanya untuk akun yang menunggu aktivasi' unless identity.status == 'pending'
      directory = IdentityDirectory.new
      unless subject
        remote_id = directory.create(username: username, email: person.email, name: person.name, membership_id: member.id)
        subject = IdentityExternalSubject.create!(id: SecureRandom.uuid, identity_account_id: identity.id,
          issuer: ENV.fetch('PKBM_OIDC_ISSUER'), protocol: 'oidc', subject: remote_id, verified_at: Time.current)
        IdentityMigrationEvent.create!(id: SecureRandom.uuid, identity_account_id: identity.id, actor_membership_id: @scope.membership_id,
          event_type: 'subject_linked', reason: 'Undangan pengelola dengan membership eksplisit, tanpa pencocokan email', reference_id: subject.id)
      end
      directory.activate_email(subject.subject)
    end
    render json: {message: 'Undangan aktivasi dikirim. Pengguna mengatur satu password melalui layanan identitas.'}, status: :accepted
  end
end
