require "digest"
require "cgi"
class CanvasSync
  class Conflict < StandardError; end
  def initialize(job)
    @job = job
    @instance = CanvasInstance.find_by!(id: job.canvas_instance_id, pkbm_id: job.pkbm_id, enabled: true)
    @api = CanvasApi.new(@instance)
    @scope = OperationScope.new(job.pkbm_id, job.requested_by)
    raise OperationWriter::Forbidden, "Peminta sinkronisasi bukan pengelola aktif" unless @scope.manager? && @scope.base("pkbm_memberships").where(id: job.requested_by, status: "active").exists?
  end

  def event(type, kind = nil, key = nil, detail = {})
    SyncEvent.create!(id: SecureRandom.uuid, pkbm_id: @job.pkbm_id, sync_job_id: @job.id, event_type: type, object_kind: kind, local_key: key, detail: detail)
  end

  def sis(kind, id) = "pkbm-#{@job.pkbm_id}-#{kind}-#{id}"
  def bindings = CanvasBinding.where(pkbm_id: @job.pkbm_id, canvas_instance_id: @instance.id)
  def escape(value) = CGI.escapeHTML(value.to_s)
  def segment(value) = URI.encode_www_form_component(value.to_s)
  def projection(remote, keys) = remote.slice(*keys)

  # Recover by stable SIS/vendor key or marked page; never retry POST blindly.
  def ensure_object(kind, key, desired, context: "", lookup:, create:, get:, update:, fields:, id_field: "id", validator: nil)
    checksum = Digest::SHA256.hexdigest(JSON.generate(desired))
    binding = bindings.find_by(object_kind: kind, local_key: key)
    remote = binding ? get.call(binding.remote_id) : lookup.call
    raise Conflict, "Binding #{kind} menunjuk objek hilang; periksa sebelum mengganti" if binding && remote.nil?
    validator.call(remote) if remote && validator
    if remote
      snapshot = projection(remote, fields)
      if binding && snapshot != binding.last_remote_snapshot && !@job.force_local
        event("conflict", kind, key, { "reason" => "remote_changed" })
        raise Conflict, "#{kind} berubah di Canvas; tinjau sebelum menerapkan rancangan PKBM"
      end
      if !binding || binding.last_payload_checksum != checksum || @job.force_local
        remote = update.call(remote.fetch(id_field).to_s, desired)
        event(binding ? "updated" : "recovered", kind, key)
      else
        event("unchanged", kind, key)
      end
    else
      remote = create.call(desired)
      validator.call(remote) if validator
      remote = update.call(remote.fetch(id_field).to_s, desired)
      event("created", kind, key)
    end
    binding ||= bindings.new(id: SecureRandom.uuid, pkbm_id: @job.pkbm_id, canvas_instance_id: @instance.id, object_kind: kind, local_key: key)
    binding.assign_attributes(remote_id: remote.fetch(id_field).to_s, remote_context: context.to_s, last_payload_checksum: checksum, last_remote_snapshot: projection(remote, fields))
    binding.save!
    remote
  end

  def keyed(kind, key, desired, lookup_path:, create_path:, update_path:, wrapper:, fields:, validator: nil)
    ensure_object(kind, key, desired,
      lookup: -> { @api.request("GET", lookup_path, nil, allow_missing: true) },
      create: ->(payload) { @api.request("POST", create_path, { wrapper => payload }) },
      get: ->(id) { @api.request("GET", update_path.call(id), nil, allow_missing: true) },
      update: ->(id, payload) { @api.request("PUT", update_path.call(id), { wrapper => payload }) }, fields: fields, validator: validator)
  end

  def run
    delivery = @scope.base("deliveries").find(@job.delivery_id)
    raise OperationWriter::Invalid, "Sinkronisasi memerlukan pelaksanaan aktif" unless delivery.status == "active"
    design = @scope.base("learning_design_versions").find(delivery.learning_design_version_id)
    raise OperationWriter::Invalid, "Rancangan belum terbit" unless design.status == "published"
    pkbm = ActiveRecord::Base.connection.select_one("SELECT name FROM pkbms WHERE id=#{ActiveRecord::Base.connection.quote(@job.pkbm_id)}")
    account_key = sis("account", @job.pkbm_id)
    account = keyed("account", @job.pkbm_id, { "name" => pkbm.fetch("name"), "sis_account_id" => account_key }, lookup_path: "/api/v1/accounts/sis_account_id:#{account_key}", create_path: "/api/v1/accounts/#{@instance.root_account_id}/sub_accounts", update_path: ->(id) { "/api/v1/accounts/#{id}" }, wrapper: "account", fields: %w[name sis_account_id], validator: ->(x) { raise Conflict, "Account di luar root Canvas lokal" unless x["parent_account_id"].to_s == @instance.root_account_id.to_s })
    course_key = sis("course", delivery.id)
    course = keyed("course", delivery.id, { "name" => delivery.name, "course_code" => "PKBM-#{delivery.id[0,8]}", "sis_course_id" => course_key }, lookup_path: "/api/v1/courses/sis_course_id:#{course_key}", create_path: "/api/v1/accounts/#{account.fetch('id')}/courses", update_path: ->(id) { "/api/v1/courses/#{id}" }, wrapper: "course", fields: %w[name course_code sis_course_id], validator: ->(x) { raise Conflict, "Course di luar account PKBM" unless x["account_id"].to_s == account["id"].to_s })
    raise Conflict, "Account binding di luar root yang dikonfigurasi" unless account['parent_account_id'].to_s == @instance.root_account_id.to_s
    raise Conflict, "Course binding di luar account PKBM" unless course['account_id'].to_s == account['id'].to_s
    cid = course.fetch("id")
    section_key = sis("section", delivery.id)
    section = keyed("section", delivery.id, { "name" => @scope.base("learning_groups").find(delivery.learning_group_id).name, "sis_section_id" => section_key }, lookup_path: "/api/v1/sections/sis_section_id:#{section_key}", create_path: "/api/v1/courses/#{cid}/sections", update_path: ->(id) { "/api/v1/sections/#{id}" }, wrapper: "course_section", fields: %w[name sis_section_id], validator: ->(x) { raise Conflict, "Section di luar Course" unless x["course_id"].to_s == cid.to_s })
    raise Conflict, "Section binding di luar Course pelaksanaan" unless section['course_id'].to_s == cid.to_s
    sync_people_and_enrollments(delivery, cid, section.fetch("id"))
    sync_targets(design, delivery, cid)
    sync_contents(design, delivery, cid)
    CanvasAssessmentPublisher.new(self, @api, @job).publish(delivery, cid)
    sync_lti(delivery, cid)
    @api.request("PUT", "/api/v1/courses/#{cid}", { "course" => { "event" => "offer" } }) unless course["workflow_state"] == "available"
    event("completed", "course", delivery.id, { "course_id" => cid, "local_design_version" => design.version })
  end

  def sync_people_and_enrollments(delivery, cid, section_id)
    staff = @scope.base("delivery_staff").where(delivery_id: delivery.id).map { |x| [x.membership_id, "TeacherEnrollment"] }
    learners = @scope.base("delivery_enrollments").where(delivery_id: delivery.id, status: "active").map { |x| [@scope.base("learner_programs").find(x.learner_program_id), "StudentEnrollment"] }.select { |lp, _| lp.status == "active" }.map { |lp, role| [lp.membership_id, role] }
    desired_keys = []
    (staff + learners).uniq.each do |membership_id, role|
      member = @scope.base("pkbm_memberships").find(membership_id)
      next unless member.status == "active"
      roles = @scope.base("role_assignments").where(membership_id: member.id).pluck(:role)
      raise Conflict, "Peran peserta/pendamping berubah; telaah penugasan" unless (role == "TeacherEnrollment" ? (roles & %w[tutor instruktur]).any? : roles.include?("warga_belajar"))
      person = @scope.base("people").find(member.person_id)
      user_key = sis("user", person.id)
      desired = { "name" => person.name }
      user = ensure_object("user", person.id, desired,
        lookup: -> { @api.request("GET", "/api/v1/users/sis_user_id:#{user_key}", nil, allow_missing: true) },
        create: ->(payload) { @api.request("POST", "/api/v1/accounts/#{@instance.root_account_id}/users", { "user" => payload, "pseudonym" => { "unique_id" => "#{person.id}@pkbm.local", "sis_user_id" => user_key, "send_confirmation" => false, "password" => SecureRandom.hex(32) } }) },
        get: ->(id) { @api.request("GET", "/api/v1/users/#{id}", nil, allow_missing: true) },
        update: ->(id, payload) { @api.request("PUT", "/api/v1/users/#{id}", { "user" => payload }) }, fields: %w[name])
      key = "#{delivery.id}:#{membership_id}:#{role}"
      desired_keys << key
      payload = { "user_id" => user.fetch("id"), "type" => role, "enrollment_state" => "active", "course_section_id" => section_id, "notify" => false }
      ensure_object("enrollment", key, payload, context: cid,
        lookup: -> { matches = @api.list("/api/v1/courses/#{cid}/enrollments?user_id=#{user.fetch('id')}&state[]=active&state[]=inactive").select { |x| x["type"] == role && x["course_section_id"].to_s == section_id.to_s }; raise Conflict, "Enrollment ganda; perlu rekonsiliasi manual" if matches.length > 1; matches.first },
        create: ->(data) { @api.request("POST", "/api/v1/sections/#{section_id}/enrollments", { "enrollment" => data }) },
        get: ->(id) { @api.request("GET", "/api/v1/accounts/#{@instance.root_account_id}/enrollments/#{id}", nil, allow_missing: true) },
        update: ->(_id, data) { @api.request("POST", "/api/v1/sections/#{section_id}/enrollments", { "enrollment" => data }) }, fields: %w[user_id type enrollment_state course_section_id])
    end
    bindings.where(object_kind: "enrollment", remote_context: cid.to_s).where.not(local_key: desired_keys).each do |binding|
      current = @api.request("GET", "/api/v1/accounts/#{@instance.root_account_id}/enrollments/#{binding.remote_id}", nil, allow_missing: true)
      next if current && current["enrollment_state"] == "inactive"
      raise Conflict, "Enrollment binding hilang" unless current
      @api.request("DELETE", "/api/v1/courses/#{cid}/enrollments/#{binding.remote_id}", { "task" => "inactivate" })
      binding.update!(last_payload_checksum: Digest::SHA256.hexdigest("inactive"), last_remote_snapshot: current.merge("enrollment_state" => "inactive").slice("user_id", "type", "enrollment_state", "course_section_id"))
      event("inactivated", "enrollment", binding.local_key)
    end
  end

  def sync_targets(design, delivery, cid)
    root = @api.request("GET", "/api/v1/courses/#{cid}/root_outcome_group")
    group_id = root.fetch("id")
    activity_ids = @scope.base("learning_activities").where(learning_design_version_id: design.id).pluck(:id)
    target_ids = @scope.base("activity_targets").where(learning_activity_id: activity_ids).distinct.pluck(:learning_target_id)
    target_ids.each do |target_id|
      target = OperationWriter.new(@scope).catalog("learning_targets", target_id)
      key = "#{delivery.id}:#{target_id}"
      desired = { "title" => [target["display_code"], target["description"]].compact.join(" ")[0,255], "display_name" => target["display_code"] || target["kind"], "description" => "<p>#{escape(target['description'])}</p><p>Acuan: #{escape(target['catalog_key'])}. Target pembelajaran; bukan keputusan ketuntasan atau SKK.</p>", "vendor_guid" => sis("outcome", target_id) }
      ensure_object("outcome", key, desired, context: cid,
        lookup: -> { matches = @api.list("/api/v1/courses/#{cid}/outcome_groups/#{group_id}/outcomes?outcome_style=full").map { |x| x["outcome"] }.compact.select { |x| x["vendor_guid"] == desired["vendor_guid"] }; raise Conflict, "Outcome vendor GUID ganda" if matches.length > 1; matches.first },
        create: ->(payload) { @api.request("POST", "/api/v1/courses/#{cid}/outcome_groups/#{group_id}/outcomes", payload).fetch("outcome") },
        get: ->(id) { @api.request("GET", "/api/v1/outcomes/#{id}", nil, allow_missing: true) },
        update: ->(id, payload) { @api.request("PUT", "/api/v1/outcomes/#{id}", payload) }, fields: %w[title display_name description vendor_guid])
    end
    event("outcome_limit", "course", delivery.id, { "note" => "Tanpa ratings/mastery_points; Canvas Outcomes tidak menjadi pengesahan akademik PKBM" })
  end

  def sync_contents(design, delivery, cid)
    module_name = "#{delivery.name} — Rencana belajar v#{design.version}"
    mod = ensure_object("module", delivery.id, { "name" => module_name, "published" => true }, context: cid,
      lookup: -> { matches = @api.list("/api/v1/courses/#{cid}/modules").select { |x| x["name"] == module_name }; raise Conflict, "Nama module ganda" if matches.length > 1; matches.first },
      create: ->(payload) { @api.request("POST", "/api/v1/courses/#{cid}/modules", { "module" => payload }) },
      get: ->(id) { @api.request("GET", "/api/v1/courses/#{cid}/modules/#{id}", nil, allow_missing: true) },
      update: ->(id, payload) { @api.request("PUT", "/api/v1/courses/#{cid}/modules/#{id}", { "module" => payload }) }, fields: %w[name published])
    module_id = mod.fetch("id")
    @scope.base("learning_activities").where(learning_design_version_id: design.id).order(:position).each do |activity|
      marker = "#{ENV.fetch('PKBM_PUBLIC_BASE_URL','http://127.0.0.1:3000')}/#delivery=#{delivery.id}&activity=#{activity.id}"
      title = activity.title
      target_rows = @scope.base("activity_targets").where(learning_activity_id: activity.id).map { |x| OperationWriter.new(@scope).catalog("learning_targets", x.learning_target_id) }
      body = "<h2>#{escape(title)}</h2><p>#{escape(activity.objective)}</p><h3>Target</h3><ul>#{target_rows.map { |x| '<li>'+escape([x['display_code'],x['description']].compact.join(' '))+'</li>' }.join}</ul><h3>Bukti yang disiapkan</h3><p>#{escape(activity.evidence_plan)}</p><h3>Pendampingan</h3><p>#{escape(activity.assessment_method)}</p><p>#{escape(activity.local_adjustment)}</p><p><a href=\"#{escape(marker)}\" target=\"_blank\">Lihat rencana di pendamping PKBM</a></p>"
      resource_links = DeliveryResource.where(pkbm_id: @job.pkbm_id, delivery_id: delivery.id).map do |selection|
        resource = OperationWriter.new(@scope).catalog("learning_resources", selection.learning_resource_id)
        url = "#{ENV.fetch('PKBM_PUBLIC_BASE_URL','http://127.0.0.1:3000')}/#resource=#{resource['id']}&delivery=#{delivery.id}"
        c = ActiveRecord::Base.connection
        findings = c.select_all("SELECT DISTINCT f.finding FROM resource_target_mappings m JOIN source_findings f ON f.id=m.source_finding_id WHERE m.learning_resource_id=#{c.quote(resource['id'])}").map { |f| escape(f['finding']) }.join('; ')
        "<li><a href=\"#{escape(url)}\" target=\"_blank\">#{escape(resource['title'])}</a> — #{escape(selection.note)}. Bahan referensi, bukan klaim seluruh KD tercakup. #{findings.present? ? "Temuan pemetaan: #{findings}" : ""}</li>"
      end
      body += "<h3>Bahan pilihan</h3><ul>#{resource_links.join}</ul><p>Penyesuaian lokal terpisah dari sumber. Penyelesaian kegiatan tidak otomatis mengesahkan SKK.</p>"
      page = ensure_object("page", "#{delivery.id}:#{activity.id}", { "title" => title, "body" => body, "published" => true, "editing_roles" => "teachers" }, context: cid,
        lookup: -> { matches = @api.list("/api/v1/courses/#{cid}/pages").filter_map { |x| full = @api.request('GET', "/api/v1/courses/#{cid}/pages/#{segment(x.fetch('url'))}"); full if full['body'].to_s.include?(marker) || full['body'].to_s.include?(escape(marker)) }; raise Conflict, "Page bertanda ganda" if matches.length > 1; matches.first },
        create: ->(payload) { @api.request("POST", "/api/v1/courses/#{cid}/pages", { "wiki_page" => payload }) },
        get: ->(id) { @api.request("GET", "/api/v1/courses/#{cid}/pages/#{segment(id)}", nil, allow_missing: true) },
        update: ->(id, payload) { @api.request("PUT", "/api/v1/courses/#{cid}/pages/#{segment(id)}", { "wiki_page" => payload }) }, fields: %w[title body published editing_roles], id_field: "url")
      item = { "type" => "Page", "page_url" => page.fetch("url"), "position" => activity.position }
      ensure_object("module_item", "#{delivery.id}:#{activity.id}", item, context: "#{cid}:#{module_id}",
        lookup: -> { matches = @api.list("/api/v1/courses/#{cid}/modules/#{module_id}/items").select { |x| x["type"] == "Page" && x["page_url"] == page["url"] }; raise Conflict, "Module item ganda" if matches.length > 1; matches.first },
        create: ->(payload) { @api.request("POST", "/api/v1/courses/#{cid}/modules/#{module_id}/items", { "module_item" => payload }) },
        get: ->(id) { @api.request("GET", "/api/v1/courses/#{cid}/modules/#{module_id}/items/#{id}", nil, allow_missing: true) },
        update: ->(id, payload) { @api.request("PUT", "/api/v1/courses/#{cid}/modules/#{module_id}/items/#{id}", { "module_item" => payload }) }, fields: %w[type page_url position])
    end
  end

  def sync_lti(delivery, cid)
    url = "#{ENV.fetch('PKBM_PUBLIC_BASE_URL','http://127.0.0.1:3000')}/lti/launch"
    payload = { "name" => "Rencana belajar PKBM", "privacy_level" => "name_only", "consumer_key" => @instance.consumer_key, "shared_secret" => @instance.credentials.fetch("lti_secret"), "url" => url, "custom_fields" => { "canvas_user_id" => "$Canvas.user.id", "canvas_course_id" => "$Canvas.course.id" }, "course_navigation" => { "enabled" => true, "text" => "Rencana belajar PKBM", "visibility" => "members", "default" => "enabled", "windowTarget" => "_blank" } }
    # Secret never stored in binding snapshots/events or returned to callers.
    safe = payload.except("shared_secret")
    ensure_object("external_tool", delivery.id, safe, context: cid,
      lookup: -> { matches = @api.list("/api/v1/courses/#{cid}/external_tools").select { |x| x['consumer_key'] == @instance.consumer_key && x['url'] == url }; raise Conflict, "External tool ganda" if matches.length > 1; matches.first },
      create: ->(_data) { @api.request("POST", "/api/v1/courses/#{cid}/external_tools", payload) },
      get: ->(id) { @api.request("GET", "/api/v1/courses/#{cid}/external_tools/#{id}", nil, allow_missing: true) },
      update: ->(id, _data) { @api.request("PUT", "/api/v1/courses/#{cid}/external_tools/#{id}", payload) }, fields: %w[name url consumer_key])
    event("lti_limit", "external_tool", delivery.id, { "protocol" => "LTI-1.1", "note" => "Implementasi lokal pada API yang tersedia; produksi memerlukan keputusan LTI 1.3" })
  end
end
