CREATE TABLE assessment_plans (
 id uuid PRIMARY KEY, pkbm_id uuid NOT NULL REFERENCES pkbms, delivery_id uuid NOT NULL,
 learning_resource_id uuid NOT NULL REFERENCES learning_resources, version integer NOT NULL CHECK(version>0),
 status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','published')),
 blueprint jsonb NOT NULL CHECK(jsonb_typeof(blueprint)='object'),
 reviewed_by uuid, reviewed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(pkbm_id,id), UNIQUE(delivery_id,learning_resource_id,version),
 FOREIGN KEY(pkbm_id,delivery_id) REFERENCES deliveries(pkbm_id,id),
 FOREIGN KEY(pkbm_id,reviewed_by) REFERENCES pkbm_memberships(pkbm_id,id),
 CHECK(status='draft' OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
);
CREATE TABLE assessment_attempts (
 id uuid PRIMARY KEY, pkbm_id uuid NOT NULL REFERENCES pkbms, assessment_plan_id uuid NOT NULL,
 item_key text NOT NULL, learner_program_id uuid NOT NULL, canvas_submission_id text NOT NULL,
 attempt integer NOT NULL CHECK(attempt>0), snapshot jsonb NOT NULL, captured_by uuid NOT NULL,
 captured_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(pkbm_id,id),
 FOREIGN KEY(pkbm_id,assessment_plan_id) REFERENCES assessment_plans(pkbm_id,id),
 FOREIGN KEY(pkbm_id,learner_program_id) REFERENCES learner_programs(pkbm_id,id),
 FOREIGN KEY(pkbm_id,captured_by) REFERENCES pkbm_memberships(pkbm_id,id)
);
CREATE TABLE assessment_actions (
 id uuid PRIMARY KEY, pkbm_id uuid NOT NULL REFERENCES pkbms, assessment_plan_id uuid NOT NULL,
 learner_program_id uuid NOT NULL, item_key text NOT NULL, action text NOT NULL CHECK(action IN ('tam_retry','module_review')),
 payload jsonb NOT NULL, actor_id uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(pkbm_id,assessment_plan_id) REFERENCES assessment_plans(pkbm_id,id),
 FOREIGN KEY(pkbm_id,learner_program_id) REFERENCES learner_programs(pkbm_id,id),
 FOREIGN KEY(pkbm_id,actor_id) REFERENCES pkbm_memberships(pkbm_id,id)
);
CREATE UNIQUE INDEX assessment_one_tam_retry ON assessment_actions(assessment_plan_id,learner_program_id,item_key) WHERE action='tam_retry';
ALTER TABLE canvas_bindings DROP CONSTRAINT canvas_bindings_object_kind_check;
ALTER TABLE canvas_bindings ADD CONSTRAINT canvas_bindings_object_kind_check CHECK(object_kind IN ('account','course','section','user','enrollment','outcome','module','page','module_item','external_tool','assessment_module','assessment_page','assessment_item','assignment','quiz','quiz_question','rubric'));
CREATE FUNCTION preserve_assessment_version() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='DELETE' OR OLD.status='published' THEN RAISE EXCEPTION 'Published assessment version is immutable'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER assessment_version_immutable BEFORE UPDATE OR DELETE ON assessment_plans FOR EACH ROW EXECUTE FUNCTION preserve_assessment_version();
