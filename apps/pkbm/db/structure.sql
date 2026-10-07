SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: check_catalog_activity_target(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_catalog_activity_target() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF (SELECT f.curriculum_component_id FROM framework_activities a JOIN academic_frameworks f ON f.id=a.academic_framework_id WHERE a.id=NEW.framework_activity_id)
 IS DISTINCT FROM (SELECT curriculum_component_id FROM learning_targets WHERE id=NEW.learning_target_id) THEN
  RAISE EXCEPTION 'Framework activity and target component differ';
 END IF;
 RETURN NEW;
END; $$;


--
-- Name: check_catalog_component_track(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_catalog_component_track() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF NEW.specialization_track_id IS NOT NULL AND
   (SELECT curriculum_version_id FROM specialization_tracks WHERE id=NEW.specialization_track_id) IS DISTINCT FROM
   (SELECT l.curriculum_version_id FROM curriculum_groups g JOIN curriculum_levels l ON l.id=g.curriculum_level_id WHERE g.id=NEW.curriculum_group_id) THEN
  RAISE EXCEPTION 'Specialization track and component curriculum differ';
 END IF;
 RETURN NEW;
END; $$;


--
-- Name: check_catalog_target_parent(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_catalog_target_parent() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: check_source_reference_pages(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_source_reference_pages() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF NEW.pdf_page_end > (SELECT pdf_pages FROM source_documents WHERE id=NEW.source_document_id) THEN
  RAISE EXCEPTION 'Source reference exceeds PDF page count';
 END IF;
 RETURN NEW;
END; $$;


--
-- Name: protect_published_local_design(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_published_local_design() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE design_id uuid;
BEGIN
 IF TG_TABLE_NAME='learning_design_versions' THEN
  IF OLD.status='published' THEN RAISE EXCEPTION 'Published design requires a new version'; END IF;
 ELSE
  IF TG_TABLE_NAME='activity_targets' THEN
   SELECT learning_design_version_id INTO design_id FROM learning_activities WHERE pkbm_id=NEW.pkbm_id AND id=NEW.learning_activity_id;
  ELSE
   design_id := NEW.learning_design_version_id;
  END IF;
  IF EXISTS(SELECT 1 FROM learning_design_versions WHERE pkbm_id=NEW.pkbm_id AND id=design_id AND status='published') THEN
   RAISE EXCEPTION 'Published design requires a new version';
  END IF;
 END IF;
 RETURN NEW;
END; $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: academic_frameworks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.academic_frameworks (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    curriculum_component_id uuid NOT NULL,
    kind text NOT NULL,
    name text NOT NULL,
    version text,
    availability text NOT NULL,
    source_reference_id uuid,
    CONSTRAINT academic_frameworks_kind_check CHECK ((kind = ANY (ARRAY['kurikulum'::text, 'silabus'::text, 'panduan'::text, 'standar_program'::text])))
);


--
-- Name: activity_targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_targets (
    id uuid NOT NULL,
    pkbm_id uuid NOT NULL,
    learning_activity_id uuid NOT NULL,
    learning_target_id uuid NOT NULL,
    relation_type text NOT NULL,
    mapping_status text DEFAULT 'rancangan_lokal'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT activity_targets_mapping_status_check CHECK ((mapping_status = ANY (ARRAY['rancangan_lokal'::text, 'ditelaah_tutor'::text]))),
    CONSTRAINT activity_targets_relation_type_check CHECK ((relation_type = ANY (ARRAY['landasan'::text, 'diajarkan'::text, 'dinilai'::text])))
);


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: component_relations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.component_relations (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    from_component_id uuid NOT NULL,
    to_component_id uuid NOT NULL,
    relation_type text NOT NULL,
    source_reference_id uuid NOT NULL,
    CONSTRAINT component_relations_check CHECK ((from_component_id <> to_component_id))
);


--
-- Name: curriculum_components; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.curriculum_components (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    curriculum_group_id uuid NOT NULL,
    specialization_track_id uuid,
    kind text NOT NULL,
    name text NOT NULL,
    local_code text NOT NULL,
    subtype text,
    source_reference_id uuid NOT NULL,
    coverage_status text DEFAULT 'struktur_saja'::text NOT NULL,
    subject_skk numeric(8,2),
    CONSTRAINT curriculum_components_kind_check CHECK ((kind = ANY (ARRAY['mapel'::text, 'pemberdayaan'::text, 'keterampilan'::text]))),
    CONSTRAINT curriculum_components_subject_skk_check CHECK (((subject_skk IS NULL) OR (subject_skk > (0)::numeric)))
);


--
-- Name: curriculum_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.curriculum_groups (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    curriculum_level_id uuid NOT NULL,
    kind text NOT NULL,
    name text NOT NULL,
    skk_budget numeric(8,2) NOT NULL,
    source_reference_id uuid NOT NULL,
    CONSTRAINT curriculum_groups_kind_check CHECK ((kind = ANY (ARRAY['umum'::text, 'peminatan'::text, 'khusus'::text]))),
    CONSTRAINT curriculum_groups_skk_budget_check CHECK ((skk_budget > (0)::numeric))
);


--
-- Name: curriculum_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.curriculum_levels (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    curriculum_version_id uuid NOT NULL,
    code text NOT NULL,
    equivalence text NOT NULL
);


--
-- Name: curriculum_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.curriculum_versions (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    name text NOT NULL,
    official_revision text,
    status text NOT NULL,
    source_document_id uuid NOT NULL
);


--
-- Name: deliveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deliveries (
    id uuid NOT NULL,
    pkbm_id uuid NOT NULL,
    learning_design_version_id uuid NOT NULL,
    learning_group_id uuid NOT NULL,
    name text NOT NULL,
    period text NOT NULL,
    location text DEFAULT ''::text NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT deliveries_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'closed'::text])))
);


--
-- Name: delivery_enrollments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.delivery_enrollments (
    id uuid NOT NULL,
    pkbm_id uuid NOT NULL,
    delivery_id uuid NOT NULL,
    learner_program_id uuid NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT delivery_enrollments_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'completed'::text])))
);


--
-- Name: delivery_staff; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.delivery_staff (
    id uuid NOT NULL,
    pkbm_id uuid NOT NULL,
    delivery_id uuid NOT NULL,
    membership_id uuid NOT NULL,
    responsibility text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: design_components; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.design_components (
    id uuid NOT NULL,
    pkbm_id uuid NOT NULL,
    learning_design_version_id uuid NOT NULL,
    curriculum_component_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: framework_activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.framework_activities (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    academic_framework_id uuid NOT NULL,
    description text NOT NULL,
    "position" integer NOT NULL,
    source_reference_id uuid NOT NULL,
    transcription_type text DEFAULT 'ringkasan_editorial'::text NOT NULL,
    CONSTRAINT framework_activities_position_check CHECK (("position" > 0))
);


--
-- Name: framework_activity_targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.framework_activity_targets (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    framework_activity_id uuid NOT NULL,
    learning_target_id uuid NOT NULL
);


--
-- Name: framework_targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.framework_targets (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    academic_framework_id uuid NOT NULL,
    learning_target_id uuid NOT NULL,
    curriculum_component_id uuid NOT NULL,
    relation_type text NOT NULL,
    source_reference_id uuid NOT NULL
);


--
-- Name: framework_topics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.framework_topics (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    academic_framework_id uuid NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    "position" integer NOT NULL,
    source_reference_id uuid NOT NULL,
    CONSTRAINT framework_topics_position_check CHECK (("position" > 0))
);


--
-- Name: group_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_memberships (
    id uuid NOT NULL,
    pkbm_id uuid NOT NULL,
    learning_group_id uuid NOT NULL,
    learner_program_id uuid NOT NULL,
    starts_on date NOT NULL,
    ends_on date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT group_memberships_check CHECK (((ends_on IS NULL) OR (ends_on >= starts_on)))
);


--
-- Name: learner_programs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.learner_programs (
    id uuid NOT NULL,
    pkbm_id uuid NOT NULL,
    program_offering_id uuid NOT NULL,
    membership_id uuid NOT NULL,
    curriculum_level_id uuid NOT NULL,
    specialization_track_id uuid,
    starts_on date NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT learner_programs_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'completed'::text])))
);


--
-- Name: learning_activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.learning_activities (
    id uuid NOT NULL,
    pkbm_id uuid NOT NULL,
    learning_design_version_id uuid NOT NULL,
    title text NOT NULL,
    "position" integer NOT NULL,
    objective text NOT NULL,
    mode text NOT NULL,
    evidence_plan text NOT NULL,
    assessment_method text NOT NULL,
    local_adjustment text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT learning_activities_mode_check CHECK ((mode = ANY (ARRAY['tatap_muka'::text, 'tutorial'::text, 'mandiri'::text, 'praktik'::text]))),
    CONSTRAINT learning_activities_position_check CHECK (("position" > 0))
);


--
-- Name: learning_design_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.learning_design_versions (
    id uuid NOT NULL,
    pkbm_id uuid NOT NULL,
    program_offering_id uuid NOT NULL,
    owner_membership_id uuid NOT NULL,
    name text NOT NULL,
    version integer NOT NULL,
    kind text NOT NULL,
    local_adjustment text DEFAULT ''::text NOT NULL,
    adjustment_origin text DEFAULT 'rancangan_tutor_pkbm'::text NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT learning_design_versions_adjustment_origin_check CHECK ((adjustment_origin = 'rancangan_tutor_pkbm'::text)),
    CONSTRAINT learning_design_versions_kind_check CHECK ((kind = ANY (ARRAY['mapel'::text, 'pemberdayaan'::text, 'keterampilan'::text, 'terpadu'::text]))),
    CONSTRAINT learning_design_versions_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'published'::text]))),
    CONSTRAINT learning_design_versions_version_check CHECK ((version > 0))
);


--
-- Name: learning_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.learning_groups (
    id uuid NOT NULL,
    pkbm_id uuid NOT NULL,
    program_offering_id uuid NOT NULL,
    name text NOT NULL,
    period text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: learning_plan_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.learning_plan_items (
    id uuid NOT NULL,
    pkbm_id uuid NOT NULL,
    learning_plan_id uuid NOT NULL,
    delivery_id uuid NOT NULL,
    learning_target_id uuid NOT NULL,
    "position" integer NOT NULL,
    planned_on date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT learning_plan_items_position_check CHECK (("position" > 0))
);


--
-- Name: learning_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.learning_plans (
    id uuid NOT NULL,
    pkbm_id uuid NOT NULL,
    learner_program_id uuid NOT NULL,
    version integer NOT NULL,
    starts_on date NOT NULL,
    ends_on date,
    objective text NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT learning_plans_check CHECK (((ends_on IS NULL) OR (ends_on >= starts_on))),
    CONSTRAINT learning_plans_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'superseded'::text]))),
    CONSTRAINT learning_plans_version_check CHECK ((version > 0))
);


--
-- Name: learning_resources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.learning_resources (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    kind text NOT NULL,
    title text NOT NULL,
    source_document_id uuid,
    version text
);


--
-- Name: learning_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.learning_sessions (
    id uuid NOT NULL,
    pkbm_id uuid NOT NULL,
    delivery_id uuid NOT NULL,
    learning_activity_id uuid NOT NULL,
    starts_at timestamp with time zone NOT NULL,
    mode text NOT NULL,
    planned_jp numeric(8,2) NOT NULL,
    location text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT learning_sessions_mode_check CHECK ((mode = ANY (ARRAY['tatap_muka'::text, 'tutorial'::text, 'mandiri'::text, 'praktik'::text]))),
    CONSTRAINT learning_sessions_planned_jp_check CHECK ((planned_jp > (0)::numeric))
);


--
-- Name: learning_targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.learning_targets (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    curriculum_component_id uuid NOT NULL,
    kind text NOT NULL,
    dimension text NOT NULL,
    parent_id uuid,
    source_code text,
    display_code text,
    description text NOT NULL,
    transcription_type text NOT NULL,
    source_reference_id uuid NOT NULL,
    CONSTRAINT learning_targets_check CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT learning_targets_dimension_check CHECK ((dimension = ANY (ARRAY['spiritual'::text, 'sosial'::text, 'pengetahuan'::text, 'keterampilan'::text, 'sikap'::text, 'lintas_dimensi'::text]))),
    CONSTRAINT learning_targets_kind_check CHECK ((kind = ANY (ARRAY['KI'::text, 'KD'::text, 'indikator'::text, 'area_panduan'::text, 'capaian_panduan'::text]))),
    CONSTRAINT learning_targets_transcription_type_check CHECK ((transcription_type = ANY (ARRAY['normalisasi_tipografi'::text, 'ringkasan_editorial'::text, 'kutipan'::text])))
);


--
-- Name: people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.people (
    id uuid NOT NULL,
    pkbm_id uuid NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    password_digest text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT people_name_check CHECK ((length(TRIM(BOTH FROM name)) > 0))
);


--
-- Name: pkbm_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pkbm_memberships (
    id uuid NOT NULL,
    pkbm_id uuid NOT NULL,
    person_id uuid NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT pkbm_memberships_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text])))
);


--
-- Name: pkbms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pkbms (
    id uuid NOT NULL,
    name text NOT NULL,
    local_code text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: program_offerings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.program_offerings (
    id uuid NOT NULL,
    pkbm_id uuid NOT NULL,
    curriculum_version_id uuid NOT NULL,
    name text NOT NULL,
    period text NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT program_offerings_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'closed'::text])))
);


--
-- Name: resource_components; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resource_components (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    learning_resource_id uuid NOT NULL,
    curriculum_component_id uuid NOT NULL
);


--
-- Name: resource_target_mappings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resource_target_mappings (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    learning_resource_id uuid NOT NULL,
    resource_unit_id uuid,
    learning_target_id uuid NOT NULL,
    relationship text NOT NULL,
    status text NOT NULL,
    rationale text NOT NULL,
    source_reference_id uuid NOT NULL,
    source_finding_id uuid,
    provenance jsonb DEFAULT '[]'::jsonb NOT NULL,
    proves_learner_mastery boolean DEFAULT false NOT NULL,
    CONSTRAINT resource_target_mappings_proves_learner_mastery_check CHECK ((proves_learner_mastery = false))
);


--
-- Name: resource_units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resource_units (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    learning_resource_id uuid NOT NULL,
    title text NOT NULL,
    source_reference_id uuid NOT NULL
);


--
-- Name: role_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_assignments (
    id uuid NOT NULL,
    pkbm_id uuid NOT NULL,
    membership_id uuid NOT NULL,
    role text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT role_assignments_role_check CHECK ((role = ANY (ARRAY['pengelola'::text, 'tutor'::text, 'instruktur'::text, 'warga_belajar'::text])))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: source_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.source_documents (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    document_type text NOT NULL,
    title text NOT NULL,
    original_filename text NOT NULL,
    path text NOT NULL,
    sha256 text NOT NULL,
    pdf_pages integer NOT NULL,
    scope text NOT NULL,
    official_revision text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT source_documents_pdf_pages_check CHECK ((pdf_pages > 0)),
    CONSTRAINT source_documents_sha256_check CHECK ((sha256 ~ '^[0-9a-f]{64}$'::text))
);


--
-- Name: source_findings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.source_findings (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    source_reference_id uuid,
    kind text NOT NULL,
    finding text NOT NULL,
    working_interpretation text NOT NULL,
    status text NOT NULL,
    provenance jsonb DEFAULT '[]'::jsonb NOT NULL,
    decision_history jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: source_policy_statements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.source_policy_statements (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    basis text NOT NULL,
    scope text NOT NULL,
    statement text NOT NULL,
    implementation_note text NOT NULL,
    unresolved jsonb DEFAULT '[]'::jsonb NOT NULL,
    provenance jsonb DEFAULT '[]'::jsonb NOT NULL,
    executable boolean DEFAULT false NOT NULL,
    CONSTRAINT source_policy_statements_executable_check CHECK ((executable = false))
);


--
-- Name: source_references; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.source_references (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    source_document_id uuid NOT NULL,
    pdf_page_start integer NOT NULL,
    pdf_page_end integer NOT NULL,
    printed_pages text,
    section text NOT NULL,
    summary text,
    extracted_text text,
    CONSTRAINT source_references_check CHECK ((pdf_page_end >= pdf_page_start)),
    CONSTRAINT source_references_pdf_page_start_check CHECK ((pdf_page_start > 0))
);


--
-- Name: specialization_tracks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.specialization_tracks (
    id uuid NOT NULL,
    catalog_key text NOT NULL,
    curriculum_version_id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL
);


--
-- Name: academic_frameworks academic_frameworks_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_frameworks
    ADD CONSTRAINT academic_frameworks_catalog_key_key UNIQUE (catalog_key);


--
-- Name: academic_frameworks academic_frameworks_id_curriculum_component_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_frameworks
    ADD CONSTRAINT academic_frameworks_id_curriculum_component_id_key UNIQUE (id, curriculum_component_id);


--
-- Name: academic_frameworks academic_frameworks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_frameworks
    ADD CONSTRAINT academic_frameworks_pkey PRIMARY KEY (id);


--
-- Name: activity_targets activity_targets_pkbm_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_targets
    ADD CONSTRAINT activity_targets_pkbm_id_id_key UNIQUE (pkbm_id, id);


--
-- Name: activity_targets activity_targets_pkbm_id_learning_activity_id_learning_targ_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_targets
    ADD CONSTRAINT activity_targets_pkbm_id_learning_activity_id_learning_targ_key UNIQUE (pkbm_id, learning_activity_id, learning_target_id, relation_type);


--
-- Name: activity_targets activity_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_targets
    ADD CONSTRAINT activity_targets_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: component_relations component_relations_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.component_relations
    ADD CONSTRAINT component_relations_catalog_key_key UNIQUE (catalog_key);


--
-- Name: component_relations component_relations_from_component_id_to_component_id_relat_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.component_relations
    ADD CONSTRAINT component_relations_from_component_id_to_component_id_relat_key UNIQUE (from_component_id, to_component_id, relation_type);


--
-- Name: component_relations component_relations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.component_relations
    ADD CONSTRAINT component_relations_pkey PRIMARY KEY (id);


--
-- Name: curriculum_components curriculum_components_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculum_components
    ADD CONSTRAINT curriculum_components_catalog_key_key UNIQUE (catalog_key);


--
-- Name: curriculum_components curriculum_components_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculum_components
    ADD CONSTRAINT curriculum_components_pkey PRIMARY KEY (id);


--
-- Name: curriculum_groups curriculum_groups_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculum_groups
    ADD CONSTRAINT curriculum_groups_catalog_key_key UNIQUE (catalog_key);


--
-- Name: curriculum_groups curriculum_groups_curriculum_level_id_kind_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculum_groups
    ADD CONSTRAINT curriculum_groups_curriculum_level_id_kind_key UNIQUE (curriculum_level_id, kind);


--
-- Name: curriculum_groups curriculum_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculum_groups
    ADD CONSTRAINT curriculum_groups_pkey PRIMARY KEY (id);


--
-- Name: curriculum_levels curriculum_levels_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculum_levels
    ADD CONSTRAINT curriculum_levels_catalog_key_key UNIQUE (catalog_key);


--
-- Name: curriculum_levels curriculum_levels_curriculum_version_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculum_levels
    ADD CONSTRAINT curriculum_levels_curriculum_version_id_code_key UNIQUE (curriculum_version_id, code);


--
-- Name: curriculum_levels curriculum_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculum_levels
    ADD CONSTRAINT curriculum_levels_pkey PRIMARY KEY (id);


--
-- Name: curriculum_versions curriculum_versions_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculum_versions
    ADD CONSTRAINT curriculum_versions_catalog_key_key UNIQUE (catalog_key);


--
-- Name: curriculum_versions curriculum_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculum_versions
    ADD CONSTRAINT curriculum_versions_pkey PRIMARY KEY (id);


--
-- Name: deliveries deliveries_pkbm_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deliveries
    ADD CONSTRAINT deliveries_pkbm_id_id_key UNIQUE (pkbm_id, id);


--
-- Name: deliveries deliveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deliveries
    ADD CONSTRAINT deliveries_pkey PRIMARY KEY (id);


--
-- Name: delivery_enrollments delivery_enrollments_pkbm_id_delivery_id_learner_program_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_enrollments
    ADD CONSTRAINT delivery_enrollments_pkbm_id_delivery_id_learner_program_id_key UNIQUE (pkbm_id, delivery_id, learner_program_id);


--
-- Name: delivery_enrollments delivery_enrollments_pkbm_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_enrollments
    ADD CONSTRAINT delivery_enrollments_pkbm_id_id_key UNIQUE (pkbm_id, id);


--
-- Name: delivery_enrollments delivery_enrollments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_enrollments
    ADD CONSTRAINT delivery_enrollments_pkey PRIMARY KEY (id);


--
-- Name: delivery_staff delivery_staff_pkbm_id_delivery_id_membership_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_staff
    ADD CONSTRAINT delivery_staff_pkbm_id_delivery_id_membership_id_key UNIQUE (pkbm_id, delivery_id, membership_id);


--
-- Name: delivery_staff delivery_staff_pkbm_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_staff
    ADD CONSTRAINT delivery_staff_pkbm_id_id_key UNIQUE (pkbm_id, id);


--
-- Name: delivery_staff delivery_staff_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_staff
    ADD CONSTRAINT delivery_staff_pkey PRIMARY KEY (id);


--
-- Name: design_components design_components_pkbm_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.design_components
    ADD CONSTRAINT design_components_pkbm_id_id_key UNIQUE (pkbm_id, id);


--
-- Name: design_components design_components_pkbm_id_learning_design_version_id_curric_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.design_components
    ADD CONSTRAINT design_components_pkbm_id_learning_design_version_id_curric_key UNIQUE (pkbm_id, learning_design_version_id, curriculum_component_id);


--
-- Name: design_components design_components_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.design_components
    ADD CONSTRAINT design_components_pkey PRIMARY KEY (id);


--
-- Name: framework_activities framework_activities_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_activities
    ADD CONSTRAINT framework_activities_catalog_key_key UNIQUE (catalog_key);


--
-- Name: framework_activities framework_activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_activities
    ADD CONSTRAINT framework_activities_pkey PRIMARY KEY (id);


--
-- Name: framework_activity_targets framework_activity_targets_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_activity_targets
    ADD CONSTRAINT framework_activity_targets_catalog_key_key UNIQUE (catalog_key);


--
-- Name: framework_activity_targets framework_activity_targets_framework_activity_id_learning_t_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_activity_targets
    ADD CONSTRAINT framework_activity_targets_framework_activity_id_learning_t_key UNIQUE (framework_activity_id, learning_target_id);


--
-- Name: framework_activity_targets framework_activity_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_activity_targets
    ADD CONSTRAINT framework_activity_targets_pkey PRIMARY KEY (id);


--
-- Name: framework_targets framework_targets_academic_framework_id_learning_target_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_targets
    ADD CONSTRAINT framework_targets_academic_framework_id_learning_target_id_key UNIQUE (academic_framework_id, learning_target_id);


--
-- Name: framework_targets framework_targets_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_targets
    ADD CONSTRAINT framework_targets_catalog_key_key UNIQUE (catalog_key);


--
-- Name: framework_targets framework_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_targets
    ADD CONSTRAINT framework_targets_pkey PRIMARY KEY (id);


--
-- Name: framework_topics framework_topics_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_topics
    ADD CONSTRAINT framework_topics_catalog_key_key UNIQUE (catalog_key);


--
-- Name: framework_topics framework_topics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_topics
    ADD CONSTRAINT framework_topics_pkey PRIMARY KEY (id);


--
-- Name: group_memberships group_memberships_pkbm_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_memberships
    ADD CONSTRAINT group_memberships_pkbm_id_id_key UNIQUE (pkbm_id, id);


--
-- Name: group_memberships group_memberships_pkbm_id_learning_group_id_learner_program_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_memberships
    ADD CONSTRAINT group_memberships_pkbm_id_learning_group_id_learner_program_key UNIQUE (pkbm_id, learning_group_id, learner_program_id);


--
-- Name: group_memberships group_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_memberships
    ADD CONSTRAINT group_memberships_pkey PRIMARY KEY (id);


--
-- Name: learner_programs learner_programs_pkbm_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learner_programs
    ADD CONSTRAINT learner_programs_pkbm_id_id_key UNIQUE (pkbm_id, id);


--
-- Name: learner_programs learner_programs_pkbm_id_program_offering_id_membership_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learner_programs
    ADD CONSTRAINT learner_programs_pkbm_id_program_offering_id_membership_id_key UNIQUE (pkbm_id, program_offering_id, membership_id);


--
-- Name: learner_programs learner_programs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learner_programs
    ADD CONSTRAINT learner_programs_pkey PRIMARY KEY (id);


--
-- Name: learning_activities learning_activities_pkbm_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_activities
    ADD CONSTRAINT learning_activities_pkbm_id_id_key UNIQUE (pkbm_id, id);


--
-- Name: learning_activities learning_activities_pkbm_id_learning_design_version_id_posi_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_activities
    ADD CONSTRAINT learning_activities_pkbm_id_learning_design_version_id_posi_key UNIQUE (pkbm_id, learning_design_version_id, "position");


--
-- Name: learning_activities learning_activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_activities
    ADD CONSTRAINT learning_activities_pkey PRIMARY KEY (id);


--
-- Name: learning_design_versions learning_design_versions_pkbm_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_design_versions
    ADD CONSTRAINT learning_design_versions_pkbm_id_id_key UNIQUE (pkbm_id, id);


--
-- Name: learning_design_versions learning_design_versions_pkbm_id_program_offering_id_name_v_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_design_versions
    ADD CONSTRAINT learning_design_versions_pkbm_id_program_offering_id_name_v_key UNIQUE (pkbm_id, program_offering_id, name, version);


--
-- Name: learning_design_versions learning_design_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_design_versions
    ADD CONSTRAINT learning_design_versions_pkey PRIMARY KEY (id);


--
-- Name: learning_groups learning_groups_pkbm_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_groups
    ADD CONSTRAINT learning_groups_pkbm_id_id_key UNIQUE (pkbm_id, id);


--
-- Name: learning_groups learning_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_groups
    ADD CONSTRAINT learning_groups_pkey PRIMARY KEY (id);


--
-- Name: learning_plan_items learning_plan_items_pkbm_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_plan_items
    ADD CONSTRAINT learning_plan_items_pkbm_id_id_key UNIQUE (pkbm_id, id);


--
-- Name: learning_plan_items learning_plan_items_pkbm_id_learning_plan_id_position_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_plan_items
    ADD CONSTRAINT learning_plan_items_pkbm_id_learning_plan_id_position_key UNIQUE (pkbm_id, learning_plan_id, "position");


--
-- Name: learning_plan_items learning_plan_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_plan_items
    ADD CONSTRAINT learning_plan_items_pkey PRIMARY KEY (id);


--
-- Name: learning_plans learning_plans_pkbm_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_plans
    ADD CONSTRAINT learning_plans_pkbm_id_id_key UNIQUE (pkbm_id, id);


--
-- Name: learning_plans learning_plans_pkbm_id_learner_program_id_version_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_plans
    ADD CONSTRAINT learning_plans_pkbm_id_learner_program_id_version_key UNIQUE (pkbm_id, learner_program_id, version);


--
-- Name: learning_plans learning_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_plans
    ADD CONSTRAINT learning_plans_pkey PRIMARY KEY (id);


--
-- Name: learning_resources learning_resources_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_resources
    ADD CONSTRAINT learning_resources_catalog_key_key UNIQUE (catalog_key);


--
-- Name: learning_resources learning_resources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_resources
    ADD CONSTRAINT learning_resources_pkey PRIMARY KEY (id);


--
-- Name: learning_sessions learning_sessions_pkbm_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_sessions
    ADD CONSTRAINT learning_sessions_pkbm_id_id_key UNIQUE (pkbm_id, id);


--
-- Name: learning_sessions learning_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_sessions
    ADD CONSTRAINT learning_sessions_pkey PRIMARY KEY (id);


--
-- Name: learning_targets learning_targets_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_targets
    ADD CONSTRAINT learning_targets_catalog_key_key UNIQUE (catalog_key);


--
-- Name: learning_targets learning_targets_id_curriculum_component_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_targets
    ADD CONSTRAINT learning_targets_id_curriculum_component_id_key UNIQUE (id, curriculum_component_id);


--
-- Name: learning_targets learning_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_targets
    ADD CONSTRAINT learning_targets_pkey PRIMARY KEY (id);


--
-- Name: people people_pkbm_id_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT people_pkbm_id_email_key UNIQUE (pkbm_id, email);


--
-- Name: people people_pkbm_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT people_pkbm_id_id_key UNIQUE (pkbm_id, id);


--
-- Name: people people_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT people_pkey PRIMARY KEY (id);


--
-- Name: pkbm_memberships pkbm_memberships_pkbm_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pkbm_memberships
    ADD CONSTRAINT pkbm_memberships_pkbm_id_id_key UNIQUE (pkbm_id, id);


--
-- Name: pkbm_memberships pkbm_memberships_pkbm_id_person_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pkbm_memberships
    ADD CONSTRAINT pkbm_memberships_pkbm_id_person_id_key UNIQUE (pkbm_id, person_id);


--
-- Name: pkbm_memberships pkbm_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pkbm_memberships
    ADD CONSTRAINT pkbm_memberships_pkey PRIMARY KEY (id);


--
-- Name: pkbms pkbms_local_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pkbms
    ADD CONSTRAINT pkbms_local_code_key UNIQUE (local_code);


--
-- Name: pkbms pkbms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pkbms
    ADD CONSTRAINT pkbms_pkey PRIMARY KEY (id);


--
-- Name: program_offerings program_offerings_pkbm_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_offerings
    ADD CONSTRAINT program_offerings_pkbm_id_id_key UNIQUE (pkbm_id, id);


--
-- Name: program_offerings program_offerings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_offerings
    ADD CONSTRAINT program_offerings_pkey PRIMARY KEY (id);


--
-- Name: resource_components resource_components_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_components
    ADD CONSTRAINT resource_components_catalog_key_key UNIQUE (catalog_key);


--
-- Name: resource_components resource_components_learning_resource_id_curriculum_compone_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_components
    ADD CONSTRAINT resource_components_learning_resource_id_curriculum_compone_key UNIQUE (learning_resource_id, curriculum_component_id);


--
-- Name: resource_components resource_components_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_components
    ADD CONSTRAINT resource_components_pkey PRIMARY KEY (id);


--
-- Name: resource_target_mappings resource_target_mappings_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_target_mappings
    ADD CONSTRAINT resource_target_mappings_catalog_key_key UNIQUE (catalog_key);


--
-- Name: resource_target_mappings resource_target_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_target_mappings
    ADD CONSTRAINT resource_target_mappings_pkey PRIMARY KEY (id);


--
-- Name: resource_target_mappings resource_target_mappings_resource_unit_id_learning_target_i_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_target_mappings
    ADD CONSTRAINT resource_target_mappings_resource_unit_id_learning_target_i_key UNIQUE (resource_unit_id, learning_target_id);


--
-- Name: resource_units resource_units_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_units
    ADD CONSTRAINT resource_units_catalog_key_key UNIQUE (catalog_key);


--
-- Name: resource_units resource_units_id_learning_resource_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_units
    ADD CONSTRAINT resource_units_id_learning_resource_id_key UNIQUE (id, learning_resource_id);


--
-- Name: resource_units resource_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_units
    ADD CONSTRAINT resource_units_pkey PRIMARY KEY (id);


--
-- Name: role_assignments role_assignments_pkbm_id_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_pkbm_id_id_key UNIQUE (pkbm_id, id);


--
-- Name: role_assignments role_assignments_pkbm_id_membership_id_role_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_pkbm_id_membership_id_role_key UNIQUE (pkbm_id, membership_id, role);


--
-- Name: role_assignments role_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: source_documents source_documents_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_documents
    ADD CONSTRAINT source_documents_catalog_key_key UNIQUE (catalog_key);


--
-- Name: source_documents source_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_documents
    ADD CONSTRAINT source_documents_pkey PRIMARY KEY (id);


--
-- Name: source_findings source_findings_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_findings
    ADD CONSTRAINT source_findings_catalog_key_key UNIQUE (catalog_key);


--
-- Name: source_findings source_findings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_findings
    ADD CONSTRAINT source_findings_pkey PRIMARY KEY (id);


--
-- Name: source_policy_statements source_policy_statements_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_policy_statements
    ADD CONSTRAINT source_policy_statements_catalog_key_key UNIQUE (catalog_key);


--
-- Name: source_policy_statements source_policy_statements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_policy_statements
    ADD CONSTRAINT source_policy_statements_pkey PRIMARY KEY (id);


--
-- Name: source_references source_references_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_references
    ADD CONSTRAINT source_references_catalog_key_key UNIQUE (catalog_key);


--
-- Name: source_references source_references_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_references
    ADD CONSTRAINT source_references_pkey PRIMARY KEY (id);


--
-- Name: specialization_tracks specialization_tracks_catalog_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.specialization_tracks
    ADD CONSTRAINT specialization_tracks_catalog_key_key UNIQUE (catalog_key);


--
-- Name: specialization_tracks specialization_tracks_curriculum_version_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.specialization_tracks
    ADD CONSTRAINT specialization_tracks_curriculum_version_id_code_key UNIQUE (curriculum_version_id, code);


--
-- Name: specialization_tracks specialization_tracks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.specialization_tracks
    ADD CONSTRAINT specialization_tracks_pkey PRIMARY KEY (id);


--
-- Name: activity_targets_pkbm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_targets_pkbm_id_idx ON public.activity_targets USING btree (pkbm_id);


--
-- Name: deliveries_pkbm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deliveries_pkbm_id_idx ON public.deliveries USING btree (pkbm_id);


--
-- Name: delivery_enrollments_pkbm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX delivery_enrollments_pkbm_id_idx ON public.delivery_enrollments USING btree (pkbm_id);


--
-- Name: delivery_staff_pkbm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX delivery_staff_pkbm_id_idx ON public.delivery_staff USING btree (pkbm_id);


--
-- Name: design_components_pkbm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX design_components_pkbm_id_idx ON public.design_components USING btree (pkbm_id);


--
-- Name: group_memberships_pkbm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_memberships_pkbm_id_idx ON public.group_memberships USING btree (pkbm_id);


--
-- Name: learner_programs_pkbm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX learner_programs_pkbm_id_idx ON public.learner_programs USING btree (pkbm_id);


--
-- Name: learning_activities_pkbm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX learning_activities_pkbm_id_idx ON public.learning_activities USING btree (pkbm_id);


--
-- Name: learning_design_versions_pkbm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX learning_design_versions_pkbm_id_idx ON public.learning_design_versions USING btree (pkbm_id);


--
-- Name: learning_groups_pkbm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX learning_groups_pkbm_id_idx ON public.learning_groups USING btree (pkbm_id);


--
-- Name: learning_plan_items_pkbm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX learning_plan_items_pkbm_id_idx ON public.learning_plan_items USING btree (pkbm_id);


--
-- Name: learning_plans_pkbm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX learning_plans_pkbm_id_idx ON public.learning_plans USING btree (pkbm_id);


--
-- Name: learning_sessions_pkbm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX learning_sessions_pkbm_id_idx ON public.learning_sessions USING btree (pkbm_id);


--
-- Name: learning_targets_component_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX learning_targets_component_idx ON public.learning_targets USING btree (curriculum_component_id);


--
-- Name: learning_targets_parent_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX learning_targets_parent_idx ON public.learning_targets USING btree (parent_id);


--
-- Name: mappings_target_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mappings_target_idx ON public.resource_target_mappings USING btree (learning_target_id);


--
-- Name: one_active_learning_plan; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX one_active_learning_plan ON public.learning_plans USING btree (pkbm_id, learner_program_id) WHERE (status = 'active'::text);


--
-- Name: people_pkbm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX people_pkbm_id_idx ON public.people USING btree (pkbm_id);


--
-- Name: pkbm_memberships_pkbm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pkbm_memberships_pkbm_id_idx ON public.pkbm_memberships USING btree (pkbm_id);


--
-- Name: program_offerings_pkbm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_offerings_pkbm_id_idx ON public.program_offerings USING btree (pkbm_id);


--
-- Name: references_document_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX references_document_idx ON public.source_references USING btree (source_document_id);


--
-- Name: role_assignments_pkbm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX role_assignments_pkbm_id_idx ON public.role_assignments USING btree (pkbm_id);


--
-- Name: framework_activity_targets activity_target_context; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER activity_target_context BEFORE INSERT OR UPDATE ON public.framework_activity_targets FOR EACH ROW EXECUTE FUNCTION public.check_catalog_activity_target();


--
-- Name: curriculum_components component_track_context; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER component_track_context BEFORE INSERT OR UPDATE ON public.curriculum_components FOR EACH ROW EXECUTE FUNCTION public.check_catalog_component_track();


--
-- Name: learning_activities immutable_published_activity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER immutable_published_activity BEFORE INSERT OR UPDATE ON public.learning_activities FOR EACH ROW EXECUTE FUNCTION public.protect_published_local_design();


--
-- Name: design_components immutable_published_component; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER immutable_published_component BEFORE INSERT OR UPDATE ON public.design_components FOR EACH ROW EXECUTE FUNCTION public.protect_published_local_design();


--
-- Name: learning_design_versions immutable_published_design; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER immutable_published_design BEFORE UPDATE ON public.learning_design_versions FOR EACH ROW EXECUTE FUNCTION public.protect_published_local_design();


--
-- Name: activity_targets immutable_published_target; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER immutable_published_target BEFORE INSERT OR UPDATE ON public.activity_targets FOR EACH ROW EXECUTE FUNCTION public.protect_published_local_design();


--
-- Name: source_references source_reference_page_bounds; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER source_reference_page_bounds BEFORE INSERT OR UPDATE ON public.source_references FOR EACH ROW EXECUTE FUNCTION public.check_source_reference_pages();


--
-- Name: learning_targets target_parent_context; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER target_parent_context BEFORE INSERT OR UPDATE ON public.learning_targets FOR EACH ROW EXECUTE FUNCTION public.check_catalog_target_parent();


--
-- Name: academic_frameworks academic_frameworks_curriculum_component_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_frameworks
    ADD CONSTRAINT academic_frameworks_curriculum_component_id_fkey FOREIGN KEY (curriculum_component_id) REFERENCES public.curriculum_components(id);


--
-- Name: academic_frameworks academic_frameworks_source_reference_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_frameworks
    ADD CONSTRAINT academic_frameworks_source_reference_id_fkey FOREIGN KEY (source_reference_id) REFERENCES public.source_references(id);


--
-- Name: activity_targets activity_targets_learning_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_targets
    ADD CONSTRAINT activity_targets_learning_target_id_fkey FOREIGN KEY (learning_target_id) REFERENCES public.learning_targets(id);


--
-- Name: activity_targets activity_targets_pkbm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_targets
    ADD CONSTRAINT activity_targets_pkbm_id_fkey FOREIGN KEY (pkbm_id) REFERENCES public.pkbms(id);


--
-- Name: activity_targets activity_targets_pkbm_id_learning_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_targets
    ADD CONSTRAINT activity_targets_pkbm_id_learning_activity_id_fkey FOREIGN KEY (pkbm_id, learning_activity_id) REFERENCES public.learning_activities(pkbm_id, id);


--
-- Name: component_relations component_relations_from_component_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.component_relations
    ADD CONSTRAINT component_relations_from_component_id_fkey FOREIGN KEY (from_component_id) REFERENCES public.curriculum_components(id);


--
-- Name: component_relations component_relations_source_reference_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.component_relations
    ADD CONSTRAINT component_relations_source_reference_id_fkey FOREIGN KEY (source_reference_id) REFERENCES public.source_references(id);


--
-- Name: component_relations component_relations_to_component_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.component_relations
    ADD CONSTRAINT component_relations_to_component_id_fkey FOREIGN KEY (to_component_id) REFERENCES public.curriculum_components(id);


--
-- Name: curriculum_components curriculum_components_curriculum_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculum_components
    ADD CONSTRAINT curriculum_components_curriculum_group_id_fkey FOREIGN KEY (curriculum_group_id) REFERENCES public.curriculum_groups(id);


--
-- Name: curriculum_components curriculum_components_source_reference_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculum_components
    ADD CONSTRAINT curriculum_components_source_reference_id_fkey FOREIGN KEY (source_reference_id) REFERENCES public.source_references(id);


--
-- Name: curriculum_components curriculum_components_specialization_track_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculum_components
    ADD CONSTRAINT curriculum_components_specialization_track_id_fkey FOREIGN KEY (specialization_track_id) REFERENCES public.specialization_tracks(id);


--
-- Name: curriculum_groups curriculum_groups_curriculum_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculum_groups
    ADD CONSTRAINT curriculum_groups_curriculum_level_id_fkey FOREIGN KEY (curriculum_level_id) REFERENCES public.curriculum_levels(id);


--
-- Name: curriculum_groups curriculum_groups_source_reference_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculum_groups
    ADD CONSTRAINT curriculum_groups_source_reference_id_fkey FOREIGN KEY (source_reference_id) REFERENCES public.source_references(id);


--
-- Name: curriculum_levels curriculum_levels_curriculum_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculum_levels
    ADD CONSTRAINT curriculum_levels_curriculum_version_id_fkey FOREIGN KEY (curriculum_version_id) REFERENCES public.curriculum_versions(id);


--
-- Name: curriculum_versions curriculum_versions_source_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.curriculum_versions
    ADD CONSTRAINT curriculum_versions_source_document_id_fkey FOREIGN KEY (source_document_id) REFERENCES public.source_documents(id);


--
-- Name: deliveries deliveries_pkbm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deliveries
    ADD CONSTRAINT deliveries_pkbm_id_fkey FOREIGN KEY (pkbm_id) REFERENCES public.pkbms(id);


--
-- Name: deliveries deliveries_pkbm_id_learning_design_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deliveries
    ADD CONSTRAINT deliveries_pkbm_id_learning_design_version_id_fkey FOREIGN KEY (pkbm_id, learning_design_version_id) REFERENCES public.learning_design_versions(pkbm_id, id);


--
-- Name: deliveries deliveries_pkbm_id_learning_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deliveries
    ADD CONSTRAINT deliveries_pkbm_id_learning_group_id_fkey FOREIGN KEY (pkbm_id, learning_group_id) REFERENCES public.learning_groups(pkbm_id, id);


--
-- Name: delivery_enrollments delivery_enrollments_pkbm_id_delivery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_enrollments
    ADD CONSTRAINT delivery_enrollments_pkbm_id_delivery_id_fkey FOREIGN KEY (pkbm_id, delivery_id) REFERENCES public.deliveries(pkbm_id, id);


--
-- Name: delivery_enrollments delivery_enrollments_pkbm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_enrollments
    ADD CONSTRAINT delivery_enrollments_pkbm_id_fkey FOREIGN KEY (pkbm_id) REFERENCES public.pkbms(id);


--
-- Name: delivery_enrollments delivery_enrollments_pkbm_id_learner_program_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_enrollments
    ADD CONSTRAINT delivery_enrollments_pkbm_id_learner_program_id_fkey FOREIGN KEY (pkbm_id, learner_program_id) REFERENCES public.learner_programs(pkbm_id, id);


--
-- Name: delivery_staff delivery_staff_pkbm_id_delivery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_staff
    ADD CONSTRAINT delivery_staff_pkbm_id_delivery_id_fkey FOREIGN KEY (pkbm_id, delivery_id) REFERENCES public.deliveries(pkbm_id, id);


--
-- Name: delivery_staff delivery_staff_pkbm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_staff
    ADD CONSTRAINT delivery_staff_pkbm_id_fkey FOREIGN KEY (pkbm_id) REFERENCES public.pkbms(id);


--
-- Name: delivery_staff delivery_staff_pkbm_id_membership_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_staff
    ADD CONSTRAINT delivery_staff_pkbm_id_membership_id_fkey FOREIGN KEY (pkbm_id, membership_id) REFERENCES public.pkbm_memberships(pkbm_id, id);


--
-- Name: design_components design_components_curriculum_component_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.design_components
    ADD CONSTRAINT design_components_curriculum_component_id_fkey FOREIGN KEY (curriculum_component_id) REFERENCES public.curriculum_components(id);


--
-- Name: design_components design_components_pkbm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.design_components
    ADD CONSTRAINT design_components_pkbm_id_fkey FOREIGN KEY (pkbm_id) REFERENCES public.pkbms(id);


--
-- Name: design_components design_components_pkbm_id_learning_design_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.design_components
    ADD CONSTRAINT design_components_pkbm_id_learning_design_version_id_fkey FOREIGN KEY (pkbm_id, learning_design_version_id) REFERENCES public.learning_design_versions(pkbm_id, id);


--
-- Name: framework_activities framework_activities_academic_framework_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_activities
    ADD CONSTRAINT framework_activities_academic_framework_id_fkey FOREIGN KEY (academic_framework_id) REFERENCES public.academic_frameworks(id);


--
-- Name: framework_activities framework_activities_source_reference_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_activities
    ADD CONSTRAINT framework_activities_source_reference_id_fkey FOREIGN KEY (source_reference_id) REFERENCES public.source_references(id);


--
-- Name: framework_activity_targets framework_activity_targets_framework_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_activity_targets
    ADD CONSTRAINT framework_activity_targets_framework_activity_id_fkey FOREIGN KEY (framework_activity_id) REFERENCES public.framework_activities(id);


--
-- Name: framework_activity_targets framework_activity_targets_learning_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_activity_targets
    ADD CONSTRAINT framework_activity_targets_learning_target_id_fkey FOREIGN KEY (learning_target_id) REFERENCES public.learning_targets(id);


--
-- Name: framework_targets framework_targets_academic_framework_id_curriculum_compone_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_targets
    ADD CONSTRAINT framework_targets_academic_framework_id_curriculum_compone_fkey FOREIGN KEY (academic_framework_id, curriculum_component_id) REFERENCES public.academic_frameworks(id, curriculum_component_id);


--
-- Name: framework_targets framework_targets_learning_target_id_curriculum_component__fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_targets
    ADD CONSTRAINT framework_targets_learning_target_id_curriculum_component__fkey FOREIGN KEY (learning_target_id, curriculum_component_id) REFERENCES public.learning_targets(id, curriculum_component_id);


--
-- Name: framework_targets framework_targets_source_reference_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_targets
    ADD CONSTRAINT framework_targets_source_reference_id_fkey FOREIGN KEY (source_reference_id) REFERENCES public.source_references(id);


--
-- Name: framework_topics framework_topics_academic_framework_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_topics
    ADD CONSTRAINT framework_topics_academic_framework_id_fkey FOREIGN KEY (academic_framework_id) REFERENCES public.academic_frameworks(id);


--
-- Name: framework_topics framework_topics_source_reference_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.framework_topics
    ADD CONSTRAINT framework_topics_source_reference_id_fkey FOREIGN KEY (source_reference_id) REFERENCES public.source_references(id);


--
-- Name: group_memberships group_memberships_pkbm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_memberships
    ADD CONSTRAINT group_memberships_pkbm_id_fkey FOREIGN KEY (pkbm_id) REFERENCES public.pkbms(id);


--
-- Name: group_memberships group_memberships_pkbm_id_learner_program_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_memberships
    ADD CONSTRAINT group_memberships_pkbm_id_learner_program_id_fkey FOREIGN KEY (pkbm_id, learner_program_id) REFERENCES public.learner_programs(pkbm_id, id);


--
-- Name: group_memberships group_memberships_pkbm_id_learning_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_memberships
    ADD CONSTRAINT group_memberships_pkbm_id_learning_group_id_fkey FOREIGN KEY (pkbm_id, learning_group_id) REFERENCES public.learning_groups(pkbm_id, id);


--
-- Name: learner_programs learner_programs_curriculum_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learner_programs
    ADD CONSTRAINT learner_programs_curriculum_level_id_fkey FOREIGN KEY (curriculum_level_id) REFERENCES public.curriculum_levels(id);


--
-- Name: learner_programs learner_programs_pkbm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learner_programs
    ADD CONSTRAINT learner_programs_pkbm_id_fkey FOREIGN KEY (pkbm_id) REFERENCES public.pkbms(id);


--
-- Name: learner_programs learner_programs_pkbm_id_membership_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learner_programs
    ADD CONSTRAINT learner_programs_pkbm_id_membership_id_fkey FOREIGN KEY (pkbm_id, membership_id) REFERENCES public.pkbm_memberships(pkbm_id, id);


--
-- Name: learner_programs learner_programs_pkbm_id_program_offering_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learner_programs
    ADD CONSTRAINT learner_programs_pkbm_id_program_offering_id_fkey FOREIGN KEY (pkbm_id, program_offering_id) REFERENCES public.program_offerings(pkbm_id, id);


--
-- Name: learner_programs learner_programs_specialization_track_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learner_programs
    ADD CONSTRAINT learner_programs_specialization_track_id_fkey FOREIGN KEY (specialization_track_id) REFERENCES public.specialization_tracks(id);


--
-- Name: learning_activities learning_activities_pkbm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_activities
    ADD CONSTRAINT learning_activities_pkbm_id_fkey FOREIGN KEY (pkbm_id) REFERENCES public.pkbms(id);


--
-- Name: learning_activities learning_activities_pkbm_id_learning_design_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_activities
    ADD CONSTRAINT learning_activities_pkbm_id_learning_design_version_id_fkey FOREIGN KEY (pkbm_id, learning_design_version_id) REFERENCES public.learning_design_versions(pkbm_id, id);


--
-- Name: learning_design_versions learning_design_versions_pkbm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_design_versions
    ADD CONSTRAINT learning_design_versions_pkbm_id_fkey FOREIGN KEY (pkbm_id) REFERENCES public.pkbms(id);


--
-- Name: learning_design_versions learning_design_versions_pkbm_id_owner_membership_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_design_versions
    ADD CONSTRAINT learning_design_versions_pkbm_id_owner_membership_id_fkey FOREIGN KEY (pkbm_id, owner_membership_id) REFERENCES public.pkbm_memberships(pkbm_id, id);


--
-- Name: learning_design_versions learning_design_versions_pkbm_id_program_offering_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_design_versions
    ADD CONSTRAINT learning_design_versions_pkbm_id_program_offering_id_fkey FOREIGN KEY (pkbm_id, program_offering_id) REFERENCES public.program_offerings(pkbm_id, id);


--
-- Name: learning_groups learning_groups_pkbm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_groups
    ADD CONSTRAINT learning_groups_pkbm_id_fkey FOREIGN KEY (pkbm_id) REFERENCES public.pkbms(id);


--
-- Name: learning_groups learning_groups_pkbm_id_program_offering_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_groups
    ADD CONSTRAINT learning_groups_pkbm_id_program_offering_id_fkey FOREIGN KEY (pkbm_id, program_offering_id) REFERENCES public.program_offerings(pkbm_id, id);


--
-- Name: learning_plan_items learning_plan_items_learning_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_plan_items
    ADD CONSTRAINT learning_plan_items_learning_target_id_fkey FOREIGN KEY (learning_target_id) REFERENCES public.learning_targets(id);


--
-- Name: learning_plan_items learning_plan_items_pkbm_id_delivery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_plan_items
    ADD CONSTRAINT learning_plan_items_pkbm_id_delivery_id_fkey FOREIGN KEY (pkbm_id, delivery_id) REFERENCES public.deliveries(pkbm_id, id);


--
-- Name: learning_plan_items learning_plan_items_pkbm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_plan_items
    ADD CONSTRAINT learning_plan_items_pkbm_id_fkey FOREIGN KEY (pkbm_id) REFERENCES public.pkbms(id);


--
-- Name: learning_plan_items learning_plan_items_pkbm_id_learning_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_plan_items
    ADD CONSTRAINT learning_plan_items_pkbm_id_learning_plan_id_fkey FOREIGN KEY (pkbm_id, learning_plan_id) REFERENCES public.learning_plans(pkbm_id, id);


--
-- Name: learning_plans learning_plans_pkbm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_plans
    ADD CONSTRAINT learning_plans_pkbm_id_fkey FOREIGN KEY (pkbm_id) REFERENCES public.pkbms(id);


--
-- Name: learning_plans learning_plans_pkbm_id_learner_program_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_plans
    ADD CONSTRAINT learning_plans_pkbm_id_learner_program_id_fkey FOREIGN KEY (pkbm_id, learner_program_id) REFERENCES public.learner_programs(pkbm_id, id);


--
-- Name: learning_resources learning_resources_source_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_resources
    ADD CONSTRAINT learning_resources_source_document_id_fkey FOREIGN KEY (source_document_id) REFERENCES public.source_documents(id);


--
-- Name: learning_sessions learning_sessions_pkbm_id_delivery_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_sessions
    ADD CONSTRAINT learning_sessions_pkbm_id_delivery_id_fkey FOREIGN KEY (pkbm_id, delivery_id) REFERENCES public.deliveries(pkbm_id, id);


--
-- Name: learning_sessions learning_sessions_pkbm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_sessions
    ADD CONSTRAINT learning_sessions_pkbm_id_fkey FOREIGN KEY (pkbm_id) REFERENCES public.pkbms(id);


--
-- Name: learning_sessions learning_sessions_pkbm_id_learning_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_sessions
    ADD CONSTRAINT learning_sessions_pkbm_id_learning_activity_id_fkey FOREIGN KEY (pkbm_id, learning_activity_id) REFERENCES public.learning_activities(pkbm_id, id);


--
-- Name: learning_targets learning_targets_curriculum_component_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_targets
    ADD CONSTRAINT learning_targets_curriculum_component_id_fkey FOREIGN KEY (curriculum_component_id) REFERENCES public.curriculum_components(id);


--
-- Name: learning_targets learning_targets_parent_id_curriculum_component_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_targets
    ADD CONSTRAINT learning_targets_parent_id_curriculum_component_id_fkey FOREIGN KEY (parent_id, curriculum_component_id) REFERENCES public.learning_targets(id, curriculum_component_id);


--
-- Name: learning_targets learning_targets_source_reference_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learning_targets
    ADD CONSTRAINT learning_targets_source_reference_id_fkey FOREIGN KEY (source_reference_id) REFERENCES public.source_references(id);


--
-- Name: people people_pkbm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT people_pkbm_id_fkey FOREIGN KEY (pkbm_id) REFERENCES public.pkbms(id);


--
-- Name: pkbm_memberships pkbm_memberships_pkbm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pkbm_memberships
    ADD CONSTRAINT pkbm_memberships_pkbm_id_fkey FOREIGN KEY (pkbm_id) REFERENCES public.pkbms(id);


--
-- Name: pkbm_memberships pkbm_memberships_pkbm_id_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pkbm_memberships
    ADD CONSTRAINT pkbm_memberships_pkbm_id_person_id_fkey FOREIGN KEY (pkbm_id, person_id) REFERENCES public.people(pkbm_id, id);


--
-- Name: program_offerings program_offerings_curriculum_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_offerings
    ADD CONSTRAINT program_offerings_curriculum_version_id_fkey FOREIGN KEY (curriculum_version_id) REFERENCES public.curriculum_versions(id);


--
-- Name: program_offerings program_offerings_pkbm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_offerings
    ADD CONSTRAINT program_offerings_pkbm_id_fkey FOREIGN KEY (pkbm_id) REFERENCES public.pkbms(id);


--
-- Name: resource_components resource_components_curriculum_component_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_components
    ADD CONSTRAINT resource_components_curriculum_component_id_fkey FOREIGN KEY (curriculum_component_id) REFERENCES public.curriculum_components(id);


--
-- Name: resource_components resource_components_learning_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_components
    ADD CONSTRAINT resource_components_learning_resource_id_fkey FOREIGN KEY (learning_resource_id) REFERENCES public.learning_resources(id);


--
-- Name: resource_target_mappings resource_target_mappings_learning_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_target_mappings
    ADD CONSTRAINT resource_target_mappings_learning_resource_id_fkey FOREIGN KEY (learning_resource_id) REFERENCES public.learning_resources(id);


--
-- Name: resource_target_mappings resource_target_mappings_learning_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_target_mappings
    ADD CONSTRAINT resource_target_mappings_learning_target_id_fkey FOREIGN KEY (learning_target_id) REFERENCES public.learning_targets(id);


--
-- Name: resource_target_mappings resource_target_mappings_resource_unit_id_learning_resourc_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_target_mappings
    ADD CONSTRAINT resource_target_mappings_resource_unit_id_learning_resourc_fkey FOREIGN KEY (resource_unit_id, learning_resource_id) REFERENCES public.resource_units(id, learning_resource_id);


--
-- Name: resource_target_mappings resource_target_mappings_source_finding_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_target_mappings
    ADD CONSTRAINT resource_target_mappings_source_finding_id_fkey FOREIGN KEY (source_finding_id) REFERENCES public.source_findings(id);


--
-- Name: resource_target_mappings resource_target_mappings_source_reference_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_target_mappings
    ADD CONSTRAINT resource_target_mappings_source_reference_id_fkey FOREIGN KEY (source_reference_id) REFERENCES public.source_references(id);


--
-- Name: resource_units resource_units_learning_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_units
    ADD CONSTRAINT resource_units_learning_resource_id_fkey FOREIGN KEY (learning_resource_id) REFERENCES public.learning_resources(id);


--
-- Name: resource_units resource_units_source_reference_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resource_units
    ADD CONSTRAINT resource_units_source_reference_id_fkey FOREIGN KEY (source_reference_id) REFERENCES public.source_references(id);


--
-- Name: role_assignments role_assignments_pkbm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_pkbm_id_fkey FOREIGN KEY (pkbm_id) REFERENCES public.pkbms(id);


--
-- Name: role_assignments role_assignments_pkbm_id_membership_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_pkbm_id_membership_id_fkey FOREIGN KEY (pkbm_id, membership_id) REFERENCES public.pkbm_memberships(pkbm_id, id);


--
-- Name: source_findings source_findings_source_reference_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_findings
    ADD CONSTRAINT source_findings_source_reference_id_fkey FOREIGN KEY (source_reference_id) REFERENCES public.source_references(id);


--
-- Name: source_references source_references_source_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_references
    ADD CONSTRAINT source_references_source_document_id_fkey FOREIGN KEY (source_document_id) REFERENCES public.source_documents(id);


--
-- Name: specialization_tracks specialization_tracks_curriculum_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.specialization_tracks
    ADD CONSTRAINT specialization_tracks_curriculum_version_id_fkey FOREIGN KEY (curriculum_version_id) REFERENCES public.curriculum_versions(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261007000200'),
('20261007000100');

