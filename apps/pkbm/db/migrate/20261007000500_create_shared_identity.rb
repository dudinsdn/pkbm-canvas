class CreateSharedIdentity < ActiveRecord::Migration[8.0]
  def up
    execute File.read(Rails.root.join('db/identity.sql'))
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Pemetaan identitas dan audit harus dipertahankan.'
  end
end
