class AddIdentityLogoutContext < ActiveRecord::Migration[8.0]
  def change
    add_column :identity_sessions, :oidc_sid, :text
    add_index :identity_sessions, :oidc_sid
  end
end
