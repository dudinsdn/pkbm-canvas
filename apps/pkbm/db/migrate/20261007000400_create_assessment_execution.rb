class CreateAssessmentExecution < ActiveRecord::Migration[8.0]
  def up
    execute File.read(Rails.root.join('db/assessment.sql'))
  end
  def down
    raise ActiveRecord::IrreversibleMigration, 'Riwayat bukti dan versi penilaian dipertahankan.'
  end
end
