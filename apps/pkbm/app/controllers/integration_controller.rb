class IntegrationController < OperationsController
  before_action :manager!, except: [:links, :resource]

  def index
    instance = CanvasInstance.find_by(pkbm_id: @scope.pkbm_id)
    render json: {
      instance: instance && instance.attributes.except("credentials_encrypted").merge("access_token_configured" => instance.credentials["access_token"].present?),
      jobs: SyncJob.where(pkbm_id: @scope.pkbm_id).order(created_at: :desc).limit(100),
      events: SyncEvent.where(pkbm_id: @scope.pkbm_id).order(created_at: :desc).limit(200),
      bindings: CanvasBinding.where(pkbm_id: @scope.pkbm_id).order(:object_kind, :local_key).limit(500),
      resources: DeliveryResource.where(pkbm_id: @scope.pkbm_id),
      worker_mode: "manual_run_one", academic_decisions_enabled: false
    }
  end

  def configure
    token = params.require(:access_token).to_s
    raise ArgumentError, "Token tidak boleh kosong" if token.blank? || token.bytesize > 4096
    instance = CanvasInstance.find_or_initialize_by(pkbm_id: @scope.pkbm_id)
    instance.id ||= SecureRandom.uuid
    old = instance.persisted? ? instance.credentials : {}
    instance.assign_attributes(name: "Canvas lokal", api_base_url: ENV.fetch("CANVAS_API_BASE_URL", "http://web:3000"), public_base_url: ENV.fetch("CANVAS_PUBLIC_BASE_URL", "http://127.0.0.1:8081"), root_account_id: ENV.fetch("CANVAS_ROOT_ACCOUNT_ID", "1").to_i, consumer_key: instance.consumer_key.presence || SecureRandom.uuid, enabled: true)
    instance.credentials = old.merge("access_token" => token, "lti_secret" => old["lti_secret"] || SecureRandom.hex(32))
    instance.save!
    render json: { configured: true, connection_verified: false }
  end

  def enqueue
    instance = CanvasInstance.find_by!(pkbm_id: @scope.pkbm_id, enabled: true)
    raise OperationWriter::Invalid, "Token Canvas belum tersedia; simpan otorisasi dahulu" unless instance.credentials["access_token"].present?
    delivery = @scope.base("deliveries").find(params.require(:delivery_id))
    raise OperationWriter::Invalid, "Pelaksanaan harus aktif" unless delivery.status == "active"
    pending = SyncJob.where(pkbm_id: @scope.pkbm_id, canvas_instance_id: instance.id, delivery_id: delivery.id, status: %w[queued running]).first
    job = pending || SyncJob.create!(id: SecureRandom.uuid, pkbm_id: @scope.pkbm_id, canvas_instance_id: instance.id, delivery_id: delivery.id, requested_by: @scope.membership_id, force_local: false)
    render json: { job: job.attributes, execution: "Pelaksanaan masuk antrean dan menunggu worker sinkronisasi" }, status: :accepted
  rescue ActiveRecord::RecordNotUnique
    render json: { error: "Job sudah diantrekan; muat ulang status" }, status: :conflict
  end

  def retry_job
    job = SyncJob.find_by!(pkbm_id: @scope.pkbm_id, id: params[:id])
    raise OperationWriter::Invalid, "Hanya job gagal/konflik dapat diulang" unless %w[failed conflict].include?(job.status)
    SyncJob.transaction do
      job.lock!
      raise OperationWriter::Invalid, "Job sudah berubah; muat ulang status" unless %w[failed conflict].include?(job.status)
      job.update!(status: "queued", requested_by: @scope.membership_id, force_local: params[:force_local] == true, finished_at: nil, error_code: nil, last_error: nil)
      SyncEvent.create!(id: SecureRandom.uuid, pkbm_id: @scope.pkbm_id, sync_job_id: job.id, event_type: "retry_requested", detail: { "force_local" => job.force_local, "requested_by" => @scope.membership_id })
    end
    render json: { job: job.attributes }, status: :accepted
  rescue ActiveRecord::RecordNotUnique
    render json: { error: "Pelaksanaan memiliki job aktif; muat ulang status" }, status: :conflict
  end

  def select_resource
    delivery = @scope.base("deliveries").find(params.require(:delivery_id))
    resource = OperationWriter.new(@scope).catalog("learning_resources", params.require(:learning_resource_id))
    component_ids = @scope.base("design_components").where(learning_design_version_id: delivery.learning_design_version_id).pluck(:curriculum_component_id)
    c = ActiveRecord::Base.connection
    eligible = c.select_value("SELECT EXISTS(SELECT 1 FROM resource_components WHERE learning_resource_id=#{c.quote(resource['id'])} AND curriculum_component_id IN (#{component_ids.map { |id| c.quote(id) }.presence&.join(',') || 'NULL'}))")
    raise OperationWriter::Invalid, "Bahan tidak dipetakan ke komponen rancangan" unless eligible
    item = DeliveryResource.find_or_initialize_by(pkbm_id: @scope.pkbm_id, delivery_id: delivery.id, learning_resource_id: resource.fetch("id"))
    item.id ||= SecureRandom.uuid
    item.note = params[:note].to_s
    item.save!
    render json: { resource: item.attributes, coverage_claim: "bahan_referensi_saja", mastery_claim: false }, status: :created
  end

  def links
    instance = CanvasInstance.find_by(pkbm_id: @scope.pkbm_id)
    rows = instance ? CanvasBinding.where(pkbm_id: @scope.pkbm_id, canvas_instance_id: instance.id, object_kind: "course", local_key: @scope.records("deliveries").pluck(:id)) : CanvasBinding.none
    render json: { courses: rows.map { |row| { delivery_id: row.local_key, canvas_course_id: row.remote_id, delivery_name: @scope.records("deliveries").find(row.local_key).name, url: "#{instance.public_base_url}/courses/#{row.remote_id}" } } }
  end

  def resource
    delivery = @scope.records("deliveries").find(params.require(:delivery_id))
    selected = DeliveryResource.find_by!(pkbm_id: @scope.pkbm_id, delivery_id: delivery.id, learning_resource_id: params[:id])
    record = OperationWriter.new(@scope).catalog("learning_resources", selected.learning_resource_id)
    source = OperationWriter.new(@scope).catalog("source_documents", record.fetch("source_document_id"))
    prefix = "/home/din/Downloads/modul-kesetaraan/"
    path = source.fetch("path")
    raise OperationWriter::Invalid, "Lokasi sumber tidak diizinkan" unless path.start_with?(prefix)
    base = Pathname.new(ENV.fetch("PKBM_SOURCE_ROOT", "/sources")).realpath
    file = base.join(path.delete_prefix(prefix)).realpath
    raise OperationWriter::Invalid, "Lokasi sumber tidak diizinkan" unless file.to_s.start_with?(base.to_s + "/") && file.extname.downcase == ".pdf"
    send_file file.to_s, type: "application/pdf", disposition: "inline", filename: file.basename.to_s
  rescue Errno::ENOENT
    render json: { error: "PDF sumber belum tersedia pada mount lokal" }, status: :not_found
  end

  private
  def manager!
    raise OperationWriter::Forbidden, "Integrasi dikelola pengelola PKBM" unless @scope.manager?
  end
end
