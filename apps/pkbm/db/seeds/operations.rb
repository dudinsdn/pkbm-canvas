# Opt-in local fixture: two tenants, three roles, no academic outcomes or Canvas writes.
require "securerandom"
require "digest"
require "json"
c = ActiveRecord::Base.connection
catalog = JSON.parse(File.read(Rails.root.join("db/seeds/catalog.json"))).fetch("tables")
ids = ->(label) { hex = Digest::SHA256.hexdigest("pkbm-stage4-#{label}")[0, 32]; [hex[0,8],hex[8,4],hex[12,4],hex[16,4],hex[20,12]].join("-") }
ActiveRecord::Base.transaction do
  c.execute("SELECT pg_advisory_xact_lock(73131008)")
  %w[DEMO-A DEMO-B].each do |code|
    pkbm_id = ids.call(code)
    c.execute("INSERT INTO pkbms(id,name,local_code) VALUES(#{c.quote(pkbm_id)},#{c.quote("PKBM Simulasi #{code.last}")},#{c.quote(code)}) ON CONFLICT(id) DO NOTHING")
    scope = nil
    members = {}
    { "pengelola" => "PKBM_LOCAL_ADMIN", "tutor" => "PKBM_LOCAL_TUTOR", "warga_belajar" => "PKBM_LOCAL_WB" }.each do |role, prefix|
      password = ENV.fetch("#{prefix}_PASSWORD")
      person_id, member_id = ids.call("#{code}-#{role}"), ids.call("#{code}-#{role}-member")
      people = OperationRecord.for("people")
      people.create!(id: person_id, pkbm_id: pkbm_id, name: "#{role.humanize} #{code}", email: "#{role}@pkbm.local", password_digest: LocalCredentials.digest(password)) unless people.exists?(id: person_id)
      OperationRecord.for("pkbm_memberships").find_or_create_by!(id: member_id) { |r| r.pkbm_id = pkbm_id; r.person_id = person_id; r.status = "active" }
      OperationRecord.for("role_assignments").find_or_create_by!(id: ids.call("#{code}-#{role}-role")) { |r| r.pkbm_id = pkbm_id; r.membership_id = member_id; r.role = role }
      members[role] = member_id
    end
    writer = OperationWriter.new(OperationScope.new(pkbm_id, members.fetch("pengelola")))
    create = lambda do |table, key, data|
      id = ids.call("#{code}-#{key}")
      unless OperationRecord.for(table).exists?(id: id)
        # API uses random IDs. Fixture alone supplies deterministic identities.
        record = writer.save(table, data.transform_keys(&:to_s))
        c.execute("UPDATE #{c.quote_table_name(table)} SET id=#{c.quote(id)} WHERE id=#{c.quote(record.id)}")
      end
      id
    end
    version = catalog.fetch("curriculum_versions").first.fetch("id")
    level = catalog.fetch("curriculum_levels").find { |x| x["code"] == "V" }.fetch("id")
    program = create.call("program_offerings", "program", {curriculum_version_id: version, name: "Paket C lokal", period: "2026/2027", status: "active"})
    learner = create.call("learner_programs", "learner", {program_offering_id: program, membership_id: members["warga_belajar"], curriculum_level_id: level, starts_on: "2026-10-07"})
    group = create.call("learning_groups", "group", {program_offering_id: program, name: "Kelompok V", period: "2026/2027"})
    create.call("group_memberships", "group-member", {learning_group_id: group, learner_program_id: learner, starts_on: "2026-10-07"})
    %w[Matematika Bahasa].each_with_index do |word, index|
      component = catalog.fetch("curriculum_components").find { |x| x["name"].start_with?(word) && x["catalog_key"].include?("V") && x["specialization_track_id"].nil? }
      target = catalog.fetch("learning_targets").find { |x| x["curriculum_component_id"] == component.fetch("id") && x["kind"] == "KD" && x["source_code"] == "3.1" }
      design = create.call("learning_design_versions", "design-#{index}", {program_offering_id: program, owner_membership_id: members["tutor"], name: "Rancangan #{component['name']}", version: 1, kind: "mapel", local_adjustment: "Contoh lokal; tutor perlu menyesuaikan konteks warga belajar."})
      create.call("design_components", "component-#{index}", {learning_design_version_id: design, curriculum_component_id: component["id"]})
      activity = create.call("learning_activities", "activity-#{index}", {learning_design_version_id: design, title: "Mengamati dan menjelaskan konteks sekitar", position: 1, objective: target["description"], mode: "tutorial", evidence_plan: "Penjelasan tertulis dan diskusi bersama tutor", assessment_method: "Telaah penalaran dan umpan balik tutor; belum menetapkan nilai akhir"})
      create.call("activity_targets", "target-#{index}", {learning_activity_id: activity, learning_target_id: target["id"], relation_type: "diajarkan"})
      writer.save("learning_design_versions", {"status" => "published"}, id: design) if OperationRecord.for("learning_design_versions").find(design).status == "draft"
      delivery = create.call("deliveries", "delivery-#{index}", {learning_design_version_id: design, learning_group_id: group, name: "Pembelajaran #{component['name']}", period: "2026/2027", status: "active"})
      create.call("delivery_staff", "staff-#{index}", {delivery_id: delivery, membership_id: members["tutor"], responsibility: "Pendamping pembelajaran"})
      create.call("delivery_enrollments", "enrollment-#{index}", {delivery_id: delivery, learner_program_id: learner})
      create.call("learning_sessions", "session-#{index}", {delivery_id: delivery, learning_activity_id: activity, starts_at: "2026-10-12T08:00:00+07:00", mode: "tutorial", planned_jp: 2, location: "PKBM"})
      plan = create.call("learning_plans", "plan", {learner_program_id: learner, version: 1, starts_on: "2026-10-07", objective: "Belajar sesuai kebutuhan dan membahas bukti dengan tutor", status: "active"})
      create.call("learning_plan_items", "plan-item-#{index}", {learning_plan_id: plan, delivery_id: delivery, learning_target_id: target["id"], position: index + 1, planned_on: "2026-10-12"})
    end
  end
end
puts "Fixture dua PKBM disiapkan; kredensial tidak ditampilkan."
