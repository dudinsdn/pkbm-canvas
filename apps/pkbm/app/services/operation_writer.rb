class OperationWriter
  class Invalid < StandardError; end
  class Forbidden < StandardError; end
  TUTOR_TABLES = %w[learning_design_versions design_components learning_activities activity_targets learning_sessions].freeze
  def initialize(scope)
    @scope = scope
  end

  def related(table, id)
    raise Invalid, "Relasi #{table} wajib diisi" if id.blank?
    @scope.base(table).find(id)
  end

  def catalog(table, id)
    ActiveRecord::Base.connection.select_one("SELECT * FROM #{ActiveRecord::Base.connection.quote_table_name(table)} WHERE id=#{ActiveRecord::Base.connection.quote(id)}") || raise(Invalid, "Acuan tidak tersedia")
  end

  def role!(member, roles)
    raise Invalid, "Membership harus aktif" unless member.status == "active"
    raise Invalid, "Peran tidak sesuai penugasan" unless @scope.base("role_assignments").where(membership_id: member.id, role: roles).exists?
  end

  def mutable_design!(id)
    design = related("learning_design_versions", id)
    raise Forbidden, "Rancangan di luar penugasan" unless @scope.manager? || design.owner_membership_id == @scope.membership_id
    raise Invalid, "Rancangan terbit tidak diubah; buat versi baru" unless design.status == "draft"
    design
  end

  def save(table, attributes, id: nil)
    raise Forbidden, "Peran hanya membaca" unless @scope.manager? || (@scope.tutor? && TUTOR_TABLES.include?(table))
    data = attributes.slice(*OperationRecord::FIELDS.fetch(table)).symbolize_keys
    data.delete(:password_digest)
    record = id ? @scope.records(table).find(id) : OperationRecord.for(table).new(id: SecureRandom.uuid, pkbm_id: @scope.pkbm_id)
    raise Invalid, "Keanggotaan dan penugasan tidak diubah; buat catatan baru" if id && %w[pkbm_memberships role_assignments delivery_enrollments delivery_staff group_memberships design_components activity_targets learning_plan_items].include?(table)
    # Validation uses merged attributes, so PATCH cannot bypass contextual checks.
    if id
      protected_keys = OperationRecord::FIELDS.fetch(table).grep(/_id$/) + %w[version]
      raise Invalid, "Identitas relasi/versi tidak diubah; buat catatan baru" if data.any? { |key, value| protected_keys.include?(key.to_s) && record[key.to_s].to_s != value.to_s }
    end
    if table == "learning_design_versions" && id && !@scope.manager? && record.owner_membership_id != @scope.membership_id
      raise Forbidden, "Rancangan bukan milik tutor"
    end
    record.assign_attributes(data)
    a = record.attributes.symbolize_keys
    if table == "people"
      raise Invalid, 'Password diatur melalui aktivasi akun terpusat' if ENV['PKBM_SSO_ENABLED'] == 'true' && attributes['password'].present?
      record.password_digest ||= LocalCredentials.digest(SecureRandom.hex(32)) if ENV['PKBM_SSO_ENABLED'] == 'true'
      password = attributes["password"]
      record.password_digest = LocalCredentials.digest(password) if password.present?
      raise Invalid, "Password awal wajib diisi" if record.password_digest.blank?
      record.email = record.email.to_s.strip.downcase
    end
    case table
    when "pkbm_memberships" then related("people", a[:person_id])
    when "role_assignments" then related("pkbm_memberships", a[:membership_id])
    when "learner_programs"
      program = related("program_offerings", a[:program_offering_id])
      role!(related("pkbm_memberships", a[:membership_id]), ["warga_belajar"])
      raise Invalid, "Tingkatan berbeda versi kurikulum" unless catalog("curriculum_levels", a[:curriculum_level_id])["curriculum_version_id"] == program.curriculum_version_id
      if a[:specialization_track_id].present?
        raise Invalid, "Peminatan berbeda kurikulum" unless catalog("specialization_tracks", a[:specialization_track_id])["curriculum_version_id"] == program.curriculum_version_id
      end
    when "group_memberships"
      group = related("learning_groups", a[:learning_group_id]); learner = related("learner_programs", a[:learner_program_id])
      raise Invalid, "Kelompok dan peserta berbeda program" unless group.program_offering_id == learner.program_offering_id
    when "learning_design_versions"
      raise Invalid, "Rancangan terbit tidak diubah; buat versi baru" if id && record.status_in_database != "draft"
      record.owner_membership_id = @scope.membership_id unless @scope.manager?
      role!(related("pkbm_memberships", record.owner_membership_id), %w[pengelola tutor instruktur])
      related("program_offerings", a[:program_offering_id])
      raise Invalid, "Rancangan membutuhkan komponen dan kegiatan bertarget sebelum terbit" if record.status == "published" && (!id || !@scope.base("design_components").where(learning_design_version_id: id).exists? || !@scope.base("learning_activities").where(learning_design_version_id: id).exists? || @scope.base("learning_activities").where(learning_design_version_id: id).any? { |x| !@scope.base("activity_targets").where(learning_activity_id: x.id).exists? })
    when "design_components"
      design = mutable_design!(a[:learning_design_version_id]); component = catalog("curriculum_components", a[:curriculum_component_id]); group = catalog("curriculum_groups", component["curriculum_group_id"]); level = catalog("curriculum_levels", group["curriculum_level_id"])
      raise Invalid, "Komponen berbeda versi kurikulum" unless related("program_offerings", design.program_offering_id).curriculum_version_id == level["curriculum_version_id"]
    when "learning_activities" then mutable_design!(a[:learning_design_version_id])
    when "activity_targets"
      activity = related("learning_activities", a[:learning_activity_id]); mutable_design!(activity.learning_design_version_id)
      target = catalog("learning_targets", a[:learning_target_id])
      raise Invalid, "Target di luar komponen rancangan" unless @scope.base("design_components").where(learning_design_version_id: activity.learning_design_version_id, curriculum_component_id: target["curriculum_component_id"]).exists?
    when "deliveries"
      design = related("learning_design_versions", a[:learning_design_version_id]); group = related("learning_groups", a[:learning_group_id])
      raise Invalid, "Pelaksanaan berbeda program" unless group.program_offering_id == design.program_offering_id
      raise Invalid, "Pelaksanaan aktif memerlukan rancangan terbit" if a[:status] == "active" && design.status != "published"
    when "delivery_staff"
      related("deliveries", a[:delivery_id]); role!(related("pkbm_memberships", a[:membership_id]), %w[tutor instruktur])
    when "delivery_enrollments"
      delivery = related("deliveries", a[:delivery_id]); learner = related("learner_programs", a[:learner_program_id]); group = related("learning_groups", delivery.learning_group_id)
      raise Invalid, "Peserta di luar kelompok pelaksanaan" unless learner.program_offering_id == group.program_offering_id && @scope.base("group_memberships").where(learning_group_id: group.id, learner_program_id: learner.id).exists?
      @scope.base("design_components").where(learning_design_version_id: delivery.learning_design_version_id).each do |entry|
        component = catalog("curriculum_components", entry.curriculum_component_id)
        source_group = catalog("curriculum_groups", component["curriculum_group_id"])
        raise Invalid, "Komponen pelaksanaan berbeda tingkatan peserta" unless source_group["curriculum_level_id"] == learner.curriculum_level_id
        if component["specialization_track_id"].present?
          raise Invalid, "Komponen pelaksanaan berbeda peminatan peserta" unless component["specialization_track_id"] == learner.specialization_track_id
        end
      end
    when "learning_plans" then related("learner_programs", a[:learner_program_id])
    when "learning_plan_items"
      plan = related("learning_plans", a[:learning_plan_id]); delivery = related("deliveries", a[:delivery_id]); target = catalog("learning_targets", a[:learning_target_id])
      raise Invalid, "Rencana belum memiliki enrollment pelaksanaan" unless @scope.base("delivery_enrollments").where(delivery_id: delivery.id, learner_program_id: plan.learner_program_id, status: "active").exists?
      raise Invalid, "Target rencana di luar pelaksanaan" unless @scope.base("activity_targets").where(learning_activity_id: @scope.base("learning_activities").where(learning_design_version_id: delivery.learning_design_version_id).select(:id), learning_target_id: target["id"]).exists?
    when "learning_sessions"
      delivery = related("deliveries", a[:delivery_id]); activity = related("learning_activities", a[:learning_activity_id])
      raise Forbidden, "Tutor tidak ditugaskan" unless @scope.manager? || @scope.staff_deliveries.where(id: delivery.id).exists?
      raise Invalid, "Kegiatan bukan bagian pelaksanaan" unless delivery.learning_design_version_id == activity.learning_design_version_id
    when "learning_groups" then related("program_offerings", a[:program_offering_id])
    when "program_offerings" then catalog("curriculum_versions", a[:curriculum_version_id])
    end
    record.save!
    record
  end
end
