CREATE TABLE source_documents (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, document_type text NOT NULL,
 title text NOT NULL, original_filename text NOT NULL, path text NOT NULL,
 sha256 text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'), pdf_pages integer NOT NULL CHECK(pdf_pages > 0),
 scope text NOT NULL, official_revision text, metadata jsonb NOT NULL DEFAULT '{}'
);
CREATE TABLE source_references (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, source_document_id uuid NOT NULL REFERENCES source_documents,
 pdf_page_start integer NOT NULL CHECK(pdf_page_start > 0), pdf_page_end integer NOT NULL,
 printed_pages text, section text NOT NULL, summary text, extracted_text text,
 CHECK(pdf_page_end >= pdf_page_start)
);
CREATE FUNCTION check_source_reference_pages() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.pdf_page_end > (SELECT pdf_pages FROM source_documents WHERE id=NEW.source_document_id) THEN
  RAISE EXCEPTION 'Source reference exceeds PDF page count';
 END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER source_reference_page_bounds BEFORE INSERT OR UPDATE ON source_references
 FOR EACH ROW EXECUTE FUNCTION check_source_reference_pages();
CREATE TABLE curriculum_versions (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, name text NOT NULL,
 official_revision text, status text NOT NULL, source_document_id uuid NOT NULL REFERENCES source_documents
);
CREATE TABLE curriculum_levels (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, curriculum_version_id uuid NOT NULL REFERENCES curriculum_versions,
 code text NOT NULL, equivalence text NOT NULL, UNIQUE(curriculum_version_id,code)
);
CREATE TABLE curriculum_groups (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, curriculum_level_id uuid NOT NULL REFERENCES curriculum_levels,
 kind text NOT NULL CHECK(kind IN ('umum','peminatan','khusus')), name text NOT NULL,
 skk_budget numeric(8,2) NOT NULL CHECK(skk_budget > 0), source_reference_id uuid NOT NULL REFERENCES source_references,
 UNIQUE(curriculum_level_id,kind)
);
CREATE TABLE specialization_tracks (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, curriculum_version_id uuid NOT NULL REFERENCES curriculum_versions,
 code text NOT NULL, name text NOT NULL, UNIQUE(curriculum_version_id,code)
);
CREATE TABLE curriculum_components (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, curriculum_group_id uuid NOT NULL REFERENCES curriculum_groups,
 specialization_track_id uuid REFERENCES specialization_tracks, kind text NOT NULL CHECK(kind IN ('mapel','pemberdayaan','keterampilan')),
 name text NOT NULL, local_code text NOT NULL, subtype text, source_reference_id uuid NOT NULL REFERENCES source_references,
 coverage_status text NOT NULL DEFAULT 'struktur_saja', subject_skk numeric(8,2), CHECK(subject_skk IS NULL OR subject_skk > 0)
);
CREATE TABLE component_relations (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, from_component_id uuid NOT NULL REFERENCES curriculum_components,
 to_component_id uuid NOT NULL REFERENCES curriculum_components, relation_type text NOT NULL,
 source_reference_id uuid NOT NULL REFERENCES source_references, CHECK(from_component_id <> to_component_id),
 UNIQUE(from_component_id,to_component_id,relation_type)
);
CREATE TABLE academic_frameworks (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, curriculum_component_id uuid NOT NULL REFERENCES curriculum_components,
 kind text NOT NULL CHECK(kind IN ('kurikulum','silabus','panduan','standar_program')), name text NOT NULL,
 version text, availability text NOT NULL, source_reference_id uuid REFERENCES source_references,
 UNIQUE(id,curriculum_component_id)
);
CREATE TABLE learning_targets (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, curriculum_component_id uuid NOT NULL REFERENCES curriculum_components,
 kind text NOT NULL CHECK(kind IN ('KI','KD','indikator','area_panduan','capaian_panduan')),
 dimension text NOT NULL CHECK(dimension IN ('spiritual','sosial','pengetahuan','keterampilan','sikap','lintas_dimensi')),
 parent_id uuid, source_code text, display_code text, description text NOT NULL,
 transcription_type text NOT NULL CHECK(transcription_type IN ('normalisasi_tipografi','ringkasan_editorial','kutipan')),
 source_reference_id uuid NOT NULL REFERENCES source_references,
 UNIQUE(id,curriculum_component_id),
 FOREIGN KEY(parent_id,curriculum_component_id) REFERENCES learning_targets(id,curriculum_component_id), CHECK(parent_id IS NULL OR parent_id <> id)
);
CREATE TABLE framework_targets (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, academic_framework_id uuid NOT NULL,
 learning_target_id uuid NOT NULL, curriculum_component_id uuid NOT NULL, relation_type text NOT NULL,
 source_reference_id uuid NOT NULL REFERENCES source_references,
 FOREIGN KEY(academic_framework_id,curriculum_component_id) REFERENCES academic_frameworks(id,curriculum_component_id),
 FOREIGN KEY(learning_target_id,curriculum_component_id) REFERENCES learning_targets(id,curriculum_component_id),
 UNIQUE(academic_framework_id,learning_target_id)
);
CREATE TABLE framework_topics (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, academic_framework_id uuid NOT NULL REFERENCES academic_frameworks,
 title text NOT NULL, description text NOT NULL, position integer NOT NULL CHECK(position > 0),
 source_reference_id uuid NOT NULL REFERENCES source_references
);
CREATE TABLE framework_activities (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, academic_framework_id uuid NOT NULL REFERENCES academic_frameworks,
 description text NOT NULL, position integer NOT NULL CHECK(position > 0),
 source_reference_id uuid NOT NULL REFERENCES source_references, transcription_type text NOT NULL DEFAULT 'ringkasan_editorial'
);
CREATE TABLE framework_activity_targets (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, framework_activity_id uuid NOT NULL REFERENCES framework_activities,
 learning_target_id uuid NOT NULL REFERENCES learning_targets,
 UNIQUE(framework_activity_id,learning_target_id)
);
CREATE TABLE source_findings (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, source_reference_id uuid REFERENCES source_references,
 kind text NOT NULL, finding text NOT NULL, working_interpretation text NOT NULL,
 status text NOT NULL, provenance jsonb NOT NULL DEFAULT '[]', decision_history jsonb NOT NULL DEFAULT '[]'
);
CREATE TABLE learning_resources (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, kind text NOT NULL, title text NOT NULL,
 source_document_id uuid REFERENCES source_documents, version text
);
CREATE TABLE resource_components (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, learning_resource_id uuid NOT NULL REFERENCES learning_resources,
 curriculum_component_id uuid NOT NULL REFERENCES curriculum_components, UNIQUE(learning_resource_id,curriculum_component_id)
);
CREATE TABLE resource_units (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, learning_resource_id uuid NOT NULL REFERENCES learning_resources,
 title text NOT NULL, source_reference_id uuid NOT NULL REFERENCES source_references, UNIQUE(id,learning_resource_id)
);
CREATE TABLE resource_target_mappings (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, learning_resource_id uuid NOT NULL REFERENCES learning_resources,
 resource_unit_id uuid, learning_target_id uuid NOT NULL REFERENCES learning_targets,
 relationship text NOT NULL, status text NOT NULL, rationale text NOT NULL,
 source_reference_id uuid NOT NULL REFERENCES source_references, source_finding_id uuid REFERENCES source_findings,
 provenance jsonb NOT NULL DEFAULT '[]', proves_learner_mastery boolean NOT NULL DEFAULT false CHECK(proves_learner_mastery = false),
 FOREIGN KEY(resource_unit_id,learning_resource_id) REFERENCES resource_units(id,learning_resource_id),
 UNIQUE(resource_unit_id,learning_target_id)
);
CREATE TABLE source_policy_statements (
 id uuid PRIMARY KEY, catalog_key text NOT NULL UNIQUE, basis text NOT NULL, scope text NOT NULL,
 statement text NOT NULL, implementation_note text NOT NULL, unresolved jsonb NOT NULL DEFAULT '[]',
 provenance jsonb NOT NULL DEFAULT '[]', executable boolean NOT NULL DEFAULT false CHECK(executable=false)
);
CREATE INDEX learning_targets_component_idx ON learning_targets(curriculum_component_id);
CREATE INDEX learning_targets_parent_idx ON learning_targets(parent_id);
CREATE INDEX references_document_idx ON source_references(source_document_id);
CREATE INDEX mappings_target_idx ON resource_target_mappings(learning_target_id);
CREATE FUNCTION check_catalog_component_track() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.specialization_track_id IS NOT NULL AND
   (SELECT curriculum_version_id FROM specialization_tracks WHERE id=NEW.specialization_track_id) IS DISTINCT FROM
   (SELECT l.curriculum_version_id FROM curriculum_groups g JOIN curriculum_levels l ON l.id=g.curriculum_level_id WHERE g.id=NEW.curriculum_group_id) THEN
  RAISE EXCEPTION 'Specialization track and component curriculum differ';
 END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER component_track_context BEFORE INSERT OR UPDATE ON curriculum_components
 FOR EACH ROW EXECUTE FUNCTION check_catalog_component_track();
CREATE FUNCTION check_catalog_activity_target() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF (SELECT f.curriculum_component_id FROM framework_activities a JOIN academic_frameworks f ON f.id=a.academic_framework_id WHERE a.id=NEW.framework_activity_id)
 IS DISTINCT FROM (SELECT curriculum_component_id FROM learning_targets WHERE id=NEW.learning_target_id) THEN
  RAISE EXCEPTION 'Framework activity and target component differ';
 END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER activity_target_context BEFORE INSERT OR UPDATE ON framework_activity_targets
 FOR EACH ROW EXECUTE FUNCTION check_catalog_activity_target();
CREATE FUNCTION check_catalog_target_parent() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE parent_kind text;
BEGIN
 IF NEW.parent_id IS NOT NULL THEN
  SELECT kind INTO parent_kind FROM learning_targets WHERE id=NEW.parent_id;
  IF (NEW.kind='KD' AND parent_kind IS DISTINCT FROM 'KI') OR
     (NEW.kind='indikator' AND parent_kind IS DISTINCT FROM 'KD') THEN
   RAISE EXCEPTION 'Target parent kind differs';
  END IF;
  IF EXISTS (WITH RECURSIVE parents AS (
    SELECT id,parent_id FROM learning_targets WHERE id=NEW.parent_id
    UNION SELECT t.id,t.parent_id FROM learning_targets t JOIN parents p ON t.id=p.parent_id
   ) SELECT 1 FROM parents WHERE id=NEW.id) THEN
   RAISE EXCEPTION 'Target parent cycle';
  END IF;
 END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER target_parent_context BEFORE INSERT OR UPDATE ON learning_targets
 FOR EACH ROW EXECUTE FUNCTION check_catalog_target_parent();
