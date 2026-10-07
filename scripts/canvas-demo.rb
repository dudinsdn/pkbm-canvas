# Local demonstration actors and orientation course; no grades or SKK.
account = Account.default
admin = Account.site_admin.pseudonyms.active.by_unique_id(ENV.fetch("CANVAS_LMS_ADMIN_EMAIL")).first
admin.user.update!(name: "Pengelola PKBM Demo") if admin
ActiveRecord::Base.transaction do
  actors = {}
  {"TUTOR" => "Tutor Demo", "WB" => "Warga Belajar Demo"}.each do |code, name|
    email = ENV.fetch("CANVAS_LOCAL_#{code}_EMAIL")
    existing = account.pseudonyms.active.by_unique_id(email).first
    user = existing&.user || User.create!(name: name)
    user.register! unless user.registered?
    unless existing
      password = ENV.fetch("CANVAS_LOCAL_#{code}_PASSWORD")
      user.pseudonyms.create!(account: account, unique_id: email, password: password, password_confirmation: password)
      user.communication_channels.create!(path: email, workflow_state: "active")
    end
    actors[code] = user
  end
  course = account.courses.where(course_code: "PKBM-LOCAL-ORIENTASI").first
  course ||= account.courses.create!(name: "Orientasi PKBM — Simulasi Lokal", course_code: "PKBM-LOCAL-ORIENTASI", workflow_state: "available")
  course.enroll_teacher(actors.fetch("TUTOR"), enrollment_state: "active")
  course.enroll_student(actors.fetch("WB"), enrollment_state: "active")
  puts "Local actors and orientation course configured (course #{course.id})."
end
