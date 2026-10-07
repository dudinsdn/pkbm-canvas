-- Global identity is independent of tenant profiles and local credentials.
CREATE TABLE identity_accounts (
 id uuid PRIMARY KEY, status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','active','disabled')),
 session_version integer NOT NULL DEFAULT 1 CHECK(session_version>0),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE identity_external_subjects (
 id uuid PRIMARY KEY, identity_account_id uuid NOT NULL REFERENCES identity_accounts,
 issuer text NOT NULL CHECK(length(trim(issuer))>0), protocol text NOT NULL CHECK(protocol IN ('oidc','saml')),
 subject text NOT NULL CHECK(length(trim(subject))>0), verified_at timestamptz NOT NULL,
 UNIQUE(issuer,protocol,subject), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON identity_external_subjects(identity_account_id);
CREATE TABLE identity_membership_links (
 id uuid PRIMARY KEY, identity_account_id uuid NOT NULL REFERENCES identity_accounts,
 pkbm_id uuid NOT NULL REFERENCES pkbms, membership_id uuid NOT NULL,
 FOREIGN KEY(pkbm_id,membership_id) REFERENCES pkbm_memberships(pkbm_id,id),
 UNIQUE(membership_id), UNIQUE(identity_account_id,pkbm_id),
 UNIQUE(identity_account_id,pkbm_id,membership_id),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
-- Deployment key identifies the physical Canvas installation, not the tenant's
-- canvas_instances row. Two PKBM rows may point at the same installation/root.
CREATE TABLE canvas_identity_links (
 id uuid PRIMARY KEY, identity_account_id uuid NOT NULL REFERENCES identity_accounts,
 deployment_key text NOT NULL CHECK(length(trim(deployment_key))>0), root_account_id integer NOT NULL CHECK(root_account_id>0),
 remote_user_id text NOT NULL CHECK(remote_user_id ~ '^[1-9][0-9]*$'),
 authentication_provider_id text NOT NULL CHECK(authentication_provider_id ~ '^[1-9][0-9]*$'),
 federated_identifier text NOT NULL CHECK(length(trim(federated_identifier))>0),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','ready','conflict','disabled')),
 verified_at timestamptz, CHECK(status<>'ready' OR verified_at IS NOT NULL),
 UNIQUE(deployment_key,root_account_id,identity_account_id),
 UNIQUE(deployment_key,root_account_id,remote_user_id),
 UNIQUE(deployment_key,root_account_id,authentication_provider_id,federated_identifier),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE identity_migration_events (
 id uuid PRIMARY KEY, identity_account_id uuid NOT NULL REFERENCES identity_accounts,
 actor_membership_id uuid NOT NULL REFERENCES pkbm_memberships,
 event_type text NOT NULL CHECK(event_type IN ('identity_created','membership_linked','subject_linked','canvas_linked','identity_disabled')),
 reason text NOT NULL CHECK(length(trim(reason))>0), reference_id uuid,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON identity_migration_events(identity_account_id,created_at);
CREATE FUNCTION protect_identity_audit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Identity audit events are immutable'; END; $$;
CREATE TRIGGER immutable_identity_audit BEFORE UPDATE OR DELETE ON identity_migration_events
 FOR EACH ROW EXECUTE FUNCTION protect_identity_audit();
CREATE TABLE identity_sessions (
 id uuid PRIMARY KEY, identity_account_id uuid NOT NULL REFERENCES identity_accounts,
 token_digest text NOT NULL UNIQUE CHECK(token_digest ~ '^[a-f0-9]{64}$'),
 pkbm_id uuid, membership_id uuid, session_version integer NOT NULL CHECK(session_version>0),
 expires_at timestamptz NOT NULL, revoked_at timestamptz,
 CHECK((pkbm_id IS NULL)=(membership_id IS NULL)),
 FOREIGN KEY(identity_account_id,pkbm_id,membership_id)
 REFERENCES identity_membership_links(identity_account_id,pkbm_id,membership_id),
 created_at timestamptz NOT NULL DEFAULT now(), CHECK(expires_at>created_at)
);
CREATE INDEX ON identity_sessions(identity_account_id);
