class CreateIdentityLoginFlows < ActiveRecord::Migration[8.0]
  def change
    create_table :identity_login_flows, id: :uuid do |t|
      t.string :state_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
    end
    add_index :identity_login_flows, :state_digest, unique: true
  end
end
