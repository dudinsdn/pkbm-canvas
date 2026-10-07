class CreatePkbmOperations < ActiveRecord::Migration[8.0]
  def up
    execute File.read(Rails.root.join("db/operations.sql"))
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Data pelaksanaan dipertahankan; penghapusan memerlukan sasaran eksplisit."
  end
end
