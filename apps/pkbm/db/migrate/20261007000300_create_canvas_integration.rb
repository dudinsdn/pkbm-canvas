class CreateCanvasIntegration < ActiveRecord::Migration[8.0]
  def up
    execute File.read(Rails.root.join("db/integration.sql"))
  end
  def down
    raise ActiveRecord::IrreversibleMigration, "Binding sinkronisasi dipertahankan; penghapusan memerlukan sasaran eksplisit."
  end
end
