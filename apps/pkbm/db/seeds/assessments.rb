require 'json'
require 'digest'
plans=JSON.parse(File.read(Rails.root.join('db/seeds/assessment-blueprints.json')))
ids=->(label) { x=Digest::SHA256.hexdigest("pkbm-stage6-#{label}")[0,32]; [x[0,8],x[8,4],x[12,4],x[16,4],x[20,12]].join('-') }
ActiveRecord::Base.transaction do
  ActiveRecord::Base.connection.execute('SELECT pg_advisory_xact_lock(73131009)')
  %w[DEMO-A DEMO-B].each do |code|
    c=ActiveRecord::Base.connection;pkbm=c.select_value("SELECT id FROM pkbms WHERE local_code=#{c.quote(code)}")
    raise 'Siapkan fixture operasional dahulu' unless pkbm
    plans.each do |data|
      component=c.select_value("SELECT id FROM curriculum_components WHERE catalog_key=#{c.quote('V:'+data.fetch('subject'))}")
      designs=OperationRecord.for('design_components').where(pkbm_id:pkbm,curriculum_component_id:component).pluck(:learning_design_version_id)
      delivery=OperationRecord.for('deliveries').where(pkbm_id:pkbm,learning_design_version_id:designs,status:'active').order(:created_at).first || raise('Pelaksanaan mapel belum tersedia')
      id=ids.call("#{code}:#{data.fetch('learning_resource_id')}:1")
      unless AssessmentPlan.exists?(id:id)
        AssessmentPlan.create!(id:id,pkbm_id:pkbm,delivery_id:delivery.id,learning_resource_id:data.fetch('learning_resource_id'),version:1,blueprint:data.fetch('blueprint'))
      end
    end
  end
end
puts 'Draf tiga modul untuk dua PKBM tersedia; tidak menerbitkan kebijakan atau menghubungi Canvas.'
