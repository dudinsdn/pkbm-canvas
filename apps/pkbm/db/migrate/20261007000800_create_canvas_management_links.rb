class CreateCanvasManagementLinks < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      CREATE TABLE canvas_management_links (
        id uuid PRIMARY KEY, pkbm_id uuid NOT NULL REFERENCES pkbms,
        canvas_instance_id uuid NOT NULL REFERENCES canvas_instances,
        identity_account_id uuid NOT NULL, membership_id uuid NOT NULL,
        remote_account_id text NOT NULL CHECK(remote_account_id ~ '^[1-9][0-9]*$'),
        remote_user_id text NOT NULL CHECK(remote_user_id ~ '^[1-9][0-9]*$'),
        remote_role_id text NOT NULL CHECK(remote_role_id ~ '^[1-9][0-9]*$'),
        status text NOT NULL CHECK(status IN ('ready','disabled','conflict')),
        verified_at timestamptz NOT NULL,
        FOREIGN KEY(identity_account_id,pkbm_id,membership_id) REFERENCES identity_membership_links(identity_account_id,pkbm_id,membership_id),
        UNIQUE(canvas_instance_id,membership_id),
        created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
      );
    SQL
  end
  def down
    raise ActiveRecord::IrreversibleMigration, 'Tautan kewenangan Canvas harus dipertahankan untuk audit.'
  end
end
