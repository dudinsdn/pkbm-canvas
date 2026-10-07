require "digest"
class CanvasSyncRunner
  def self.run_one(job_id = nil)
    candidates = SyncJob.where(status: "queued").or(SyncJob.where(status: "running").where("updated_at < ?", 10.minutes.ago))
    job = job_id ? candidates.find_by(id: job_id) : candidates.order(:created_at).first
    return nil unless job
    lock_key = Digest::SHA256.hexdigest("canvas-sync:#{job.pkbm_id}:#{job.canvas_instance_id}")[0,15].to_i(16)
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      locked = connection.select_value("SELECT pg_try_advisory_lock(#{lock_key})")
      return nil unless locked
      begin
        job.reload
        return nil unless job.status == "queued" || (job.status == "running" && job.updated_at < 10.minutes.ago)
        job.update!(status: "running", attempts: job.attempts + 1, started_at: Time.current, finished_at: nil, last_error: nil, error_code: nil)
        sync = CanvasSync.new(job)
        sync.run
        job.update!(status: "completed", finished_at: Time.current)
      rescue CanvasSync::Conflict => error
        job.update!(status: "conflict", finished_at: Time.current, error_code: "remote_conflict", last_error: error.message)
      rescue CanvasApi::Error => error
        job.update!(status: "failed", finished_at: Time.current, error_code: "canvas_http_#{error.status}", last_error: error.message)
      rescue OperationWriter::Invalid, OperationWriter::Forbidden, ActiveRecord::RecordNotFound => error
        job.update!(status: "failed", finished_at: Time.current, error_code: "local_context", last_error: error.message)
      rescue StandardError => error
        # Never persist exception bodies or request credentials.
        job.update!(status: "failed", finished_at: Time.current, error_code: "internal_error", last_error: "Sinkronisasi gagal (#{error.class.name}); periksa implementasi")
      ensure
        begin
          if %w[failed conflict].include?(job.status)
            SyncEvent.create!(id: SecureRandom.uuid, pkbm_id: job.pkbm_id, sync_job_id: job.id, event_type: job.status, detail: { "error_code" => job.error_code, "attempt" => job.attempts })
          end
        ensure
          connection.execute("SELECT pg_advisory_unlock(#{lock_key})")
        end
      end
    end
    job
  end
end
