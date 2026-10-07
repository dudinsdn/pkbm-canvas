CREATE TABLE canvas_instances (
 id uuid PRIMARY KEY, pkbm_id uuid NOT NULL UNIQUE REFERENCES pkbms, name text NOT NULL,
 api_base_url text NOT NULL, public_base_url text NOT NULL, root_account_id integer NOT NULL CHECK(root_account_id>0),
 credentials_encrypted text NOT NULL, consumer_key text NOT NULL UNIQUE,
 enabled boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(pkbm_id,id)
);
CREATE TABLE canvas_bindings (
 id uuid PRIMARY KEY, pkbm_id uuid NOT NULL REFERENCES pkbms, canvas_instance_id uuid NOT NULL,
 object_kind text NOT NULL CHECK(object_kind IN ('account','course','section','user','enrollment','outcome','module','page','module_item','external_tool')),
 local_key text NOT NULL, remote_id text NOT NULL, remote_context text NOT NULL DEFAULT '',
 last_payload_checksum text NOT NULL, last_remote_snapshot jsonb NOT NULL DEFAULT '{}',
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(pkbm_id,canvas_instance_id) REFERENCES canvas_instances(pkbm_id,id),
 UNIQUE(canvas_instance_id,object_kind,local_key), UNIQUE(canvas_instance_id,object_kind,remote_context,remote_id)
);
CREATE TABLE delivery_resources (
 id uuid PRIMARY KEY, pkbm_id uuid NOT NULL REFERENCES pkbms, delivery_id uuid NOT NULL,
 learning_resource_id uuid NOT NULL REFERENCES learning_resources, note text NOT NULL DEFAULT '',
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(pkbm_id,delivery_id) REFERENCES deliveries(pkbm_id,id), UNIQUE(pkbm_id,delivery_id,learning_resource_id)
);
CREATE TABLE sync_jobs (
 id uuid PRIMARY KEY, pkbm_id uuid NOT NULL REFERENCES pkbms, canvas_instance_id uuid NOT NULL,
 delivery_id uuid NOT NULL, requested_by uuid NOT NULL, status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','running','completed','failed','conflict')),
 attempts integer NOT NULL DEFAULT 0 CHECK(attempts>=0), force_local boolean NOT NULL DEFAULT false,
 started_at timestamptz, finished_at timestamptz, error_code text, last_error text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(pkbm_id,canvas_instance_id) REFERENCES canvas_instances(pkbm_id,id),
 FOREIGN KEY(pkbm_id,delivery_id) REFERENCES deliveries(pkbm_id,id),
 FOREIGN KEY(pkbm_id,requested_by) REFERENCES pkbm_memberships(pkbm_id,id), UNIQUE(pkbm_id,id)
);
CREATE UNIQUE INDEX one_pending_delivery_sync ON sync_jobs(canvas_instance_id,delivery_id) WHERE status IN ('queued','running');
CREATE TABLE sync_events (
 id uuid PRIMARY KEY, pkbm_id uuid NOT NULL REFERENCES pkbms, sync_job_id uuid NOT NULL,
 event_type text NOT NULL, object_kind text, local_key text, detail jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(pkbm_id,sync_job_id) REFERENCES sync_jobs(pkbm_id,id)
);
CREATE TABLE lti_nonces (
 id uuid PRIMARY KEY, canvas_instance_id uuid NOT NULL REFERENCES canvas_instances,
 nonce_digest text NOT NULL, expires_at timestamptz NOT NULL, UNIQUE(canvas_instance_id,nonce_digest)
);
CREATE TABLE lti_launch_codes (
 id uuid PRIMARY KEY, pkbm_id uuid NOT NULL REFERENCES pkbms, membership_id uuid NOT NULL,
 code_digest text NOT NULL UNIQUE, expires_at timestamptz NOT NULL, used_at timestamptz,
 FOREIGN KEY(pkbm_id,membership_id) REFERENCES pkbm_memberships(pkbm_id,id)
);
