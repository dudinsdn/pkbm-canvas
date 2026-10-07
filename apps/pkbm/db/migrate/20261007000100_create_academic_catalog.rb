class CreateAcademicCatalog < ActiveRecord::Migration[8.0]
  def up
    execute File.read(Rails.root.join("db/catalog.sql"))
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Katalog sumber dipertahankan; penghapusan harus mempunyai sasaran eksplisit."
  end
end
