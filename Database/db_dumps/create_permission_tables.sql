BEGIN;

--
-- SQL for creating additional tables for sequence uploads and permissions
--

SET search_path = public, pg_catalog;
SET default_tablespace = '';


-----------------------------------------------------------------------------
--
-- Table Name: upload; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TYPE upload_type AS ENUM ('public','release','private','undefined');

CREATE TABLE upload (
	upload_id        integer NOT NULL,
	login_id         integer NOT NULL DEFAULT 0,
	tag              varchar(50) NOT NULL DEFAULT '',
	release_date     DATE NOT NULL DEFAULT 'infinity'::timestamp,
	category         upload_type NOT NULL DEFAULT 'undefined',
	upload_date      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE public.upload OWNER TO postgres;

--
-- primary key
--
CREATE SEQUENCE upload_upload_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.upload_upload_id_seq OWNER TO postgres;

ALTER SEQUENCE upload_upload_id_seq OWNED BY upload.upload_id;

ALTER TABLE ONLY upload ALTER COLUMN upload_id SET DEFAULT nextval('upload_upload_id_seq'::regclass);

ALTER TABLE ONLY upload
	ADD CONSTRAINT upload_pkey PRIMARY KEY (upload_id);

--
-- foreign keys
--
ALTER TABLE ONLY upload
	ADD CONSTRAINT upload_login_id_fkey FOREIGN KEY (login_id) REFERENCES login(login_id);

COMMENT ON CONSTRAINT upload_login_id_fkey ON upload IS 'Cannot delete user if they have upload entries remaining in upload table.';

--
-- Indices 
--
CREATE INDEX upload_idx1 ON upload USING btree (login_id);


-----------------------------------------------------------------------------
--
-- Table Name: permission; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE permission (
	permission_id    integer NOT NULL,
	upload_id        integer NOT NULL,
	login_id         integer NOT NULL,
	can_modify       boolean NOT NULL,
	can_share        boolean NOT NULL
);

ALTER TABLE public.permission OWNER TO postgres;

--
-- primary key
--
CREATE SEQUENCE permission_permission_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.permission_permission_id_seq OWNER TO postgres;

ALTER SEQUENCE permission_permission_id_seq OWNED BY permission.permission_id;

ALTER TABLE ONLY permission ALTER COLUMN permission_id SET DEFAULT nextval('permission_permission_id_seq'::regclass);

ALTER TABLE ONLY permission
	ADD CONSTRAINT permission_pkey PRIMARY KEY (permission_id);

--
-- foreign keys
--
ALTER TABLE ONLY permission
	ADD CONSTRAINT permission_login_id_fkey FOREIGN KEY (login_id) REFERENCES login(login_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

COMMENT ON CONSTRAINT permission_login_id_fkey ON permission IS 'If user in login table is deleted, their permission entries will also be deleted.';

ALTER TABLE ONLY permission
	ADD CONSTRAINT permission_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES upload(upload_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

COMMENT ON CONSTRAINT permission_upload_id_fkey ON permission IS 'If entry in upload table is deleted, permission entries linked to upload will also be deleted.';

--
-- Indices 
--
CREATE INDEX permission_idx1 ON permission USING btree (login_id);

CREATE INDEX permission_idx2 ON permission USING btree (upload_id);

--
-- Constraints
--
ALTER TABLE ONLY permission
	ADD CONSTRAINT permission_c1 UNIQUE (upload_id, login_id);

COMMENT ON INDEX permission_c1 IS 'Each each user can be matched with each upload only once.';


-----------------------------------------------------------------------------
--
-- Table Name: private_feature; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE private_feature (
    feature_id integer NOT NULL,
    dbxref_id integer,
    organism_id integer NOT NULL,
    name character varying(255),
    uniquename text NOT NULL,
    residues text,
    seqlen integer,
    md5checksum character(32),
    type_id integer NOT NULL,
    is_analysis boolean DEFAULT false NOT NULL,
    is_obsolete boolean DEFAULT false NOT NULL,
    timeaccessioned timestamp without time zone DEFAULT now() NOT NULL,
    timelastmodified timestamp without time zone DEFAULT now() NOT NULL,
	upload_id	integer NOT NULL
);
ALTER TABLE ONLY private_feature ALTER COLUMN residues SET STORAGE EXTERNAL;

ALTER TABLE public.private_feature OWNER TO postgres;

COMMENT ON TABLE private_feature IS 'private_feature is identical to feature table but is 
intended to contain private data only available to specific users.  The table
private_feature contains upload_id column. This column references the upload table and
links sequences to specific users via the permission table.  All other columns are
identical in feature and private_feature.  See feature table comments for further 
information on other columns.';

--
-- primary key
--

CREATE SEQUENCE private_feature_feature_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER TABLE public.private_feature_feature_id_seq OWNER TO postgres;

ALTER SEQUENCE private_feature_feature_id_seq OWNED BY private_feature.feature_id;

ALTER TABLE ONLY private_feature ALTER COLUMN feature_id SET DEFAULT nextval('private_feature_feature_id_seq'::regclass);

ALTER TABLE ONLY private_feature
	ADD CONSTRAINT private_feature_pkey PRIMARY KEY (feature_id);


--
-- foreign keys
--
ALTER TABLE ONLY private_feature
	ADD CONSTRAINT private_feature_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES organism(organism_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_feature
	ADD CONSTRAINT private_feature_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_feature
	ADD CONSTRAINT private_feature_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_feature
	ADD CONSTRAINT private_feature_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES upload(upload_id);

COMMENT ON CONSTRAINT private_feature_upload_id_fkey ON private_feature IS 'Cannot delete upload entry if there are referenced entries in private_feature.
Must manually delete.';

--
-- constraints
--
ALTER TABLE ONLY private_feature
	ADD CONSTRAINT private_feature_c1 UNIQUE (organism_id, uniquename, type_id);

--
-- Indices 
--
CREATE INDEX private_feature_idx1 ON private_feature USING btree (dbxref_id);

CREATE INDEX private_feature_idx2 ON private_feature USING btree (organism_id);

CREATE INDEX private_feature_idx3 ON private_feature USING btree (type_id);

CREATE INDEX private_feature_idx4 ON private_feature USING btree (uniquename);

CREATE INDEX private_feature_idx5 ON private_feature USING btree (lower((name)::text));

CREATE INDEX private_feature_name_ind1 ON private_feature USING btree (name);


-----------------------------------------------------------------------------
--
-- Table Name: private_featureprop; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE private_featureprop (
    featureprop_id integer NOT NULL,
    feature_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL,
	upload_id	integer NOT NULL
);

ALTER TABLE public.private_featureprop OWNER TO postgres;

COMMENT ON TABLE private_featureprop IS 'private_featureprop is identical to featureprop
table but is intended to contain private data only available to specific users.  The table
private_featureprop contains upload_id column. This column references the upload table and
links sequences to specific users via the permission table.  All other columns are
identical in featureprop and private_featureprop.  See featureprop table comments for further 
information on other columns.';


--
-- primary key
--
CREATE SEQUENCE private_featureprop_featureprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER TABLE public.private_featureprop_featureprop_id_seq OWNER TO postgres;

ALTER SEQUENCE private_featureprop_featureprop_id_seq OWNED BY private_featureprop.featureprop_id;

ALTER TABLE ONLY private_featureprop ALTER COLUMN featureprop_id SET DEFAULT nextval('private_featureprop_featureprop_id_seq'::regclass);

ALTER TABLE ONLY private_featureprop
    ADD CONSTRAINT private_featureprop_pkey PRIMARY KEY (featureprop_id);


--
-- foreign keys
--
ALTER TABLE ONLY private_featureprop
    ADD CONSTRAINT private_featureprop_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_featureprop
    ADD CONSTRAINT private_featureprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_featureprop
	ADD CONSTRAINT private_featureprop_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES upload(upload_id);

COMMENT ON CONSTRAINT private_featureprop_upload_id_fkey ON private_featureprop IS 'Cannot delete upload entry if there are referenced entries in private_featureprop.
Must manually delete.';

--
-- constraints
--
ALTER TABLE ONLY private_featureprop
	ADD CONSTRAINT private_featureprop_c1 UNIQUE (feature_id, type_id, rank);


--
-- Indices 
--

CREATE INDEX private_featureprop_idx1 ON private_featureprop USING btree (feature_id);

CREATE INDEX private_featureprop_idx2 ON private_featureprop USING btree (type_id);


-----------------------------------------------------------------------------
--
-- Name: private_feature_relationship; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--
CREATE TABLE private_feature_relationship (
    feature_relationship_id integer NOT NULL,
    subject_id integer NOT NULL,
    object_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.private_feature_relationship OWNER TO postgres;

COMMENT ON TABLE private_feature_relationship IS 'A mirror of the feature_relationship table.
 Only difference is that this table references features in the private_feature table.  See
comments on feature_relationship table for more information.';


--
-- primary key
--
CREATE SEQUENCE private_feature_relationship_feature_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.private_feature_relationship_feature_relationship_id_seq OWNER TO postgres;

ALTER SEQUENCE private_feature_relationship_feature_relationship_id_seq OWNED BY private_feature_relationship.feature_relationship_id;

ALTER TABLE ONLY private_feature_relationship ALTER COLUMN feature_relationship_id SET DEFAULT nextval('private_feature_relationship_feature_relationship_id_seq'::regclass);

ALTER TABLE ONLY private_feature_relationship
    ADD CONSTRAINT private_feature_relationship_pkey PRIMARY KEY (feature_relationship_id);


--
-- foreign keys
--
ALTER TABLE ONLY private_feature_relationship
    ADD CONSTRAINT private_feature_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_feature_relationship
    ADD CONSTRAINT private_feature_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_feature_relationship
    ADD CONSTRAINT private_feature_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- constraints
--
ALTER TABLE ONLY private_feature_relationship
    ADD CONSTRAINT private_feature_relationship_c1 UNIQUE (subject_id, object_id, type_id, rank);


--
-- Indices 
--
CREATE INDEX private_feature_relationship_idx1 ON private_feature_relationship USING btree (subject_id);

CREATE INDEX private_feature_relationship_idx2 ON private_feature_relationship USING btree (object_id);

CREATE INDEX private_feature_relationship_idx3 ON private_feature_relationship USING btree (type_id);


-----------------------------------------------------------------------------
--
-- Name: feature_dbxref; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE private_feature_dbxref (
    feature_dbxref_id integer NOT NULL,
    feature_id integer NOT NULL,
    dbxref_id integer NOT NULL,
    is_current boolean DEFAULT true NOT NULL
);

ALTER TABLE public.private_feature_dbxref OWNER TO postgres;


COMMENT ON TABLE private_feature_dbxref IS 'A mirror of the feature_dbxref table.
 Only difference is that this table references features in the private_feature table.  See
comments on feature_dbxref table for more information.';


--
-- primary key
--
CREATE SEQUENCE private_feature_dbxref_feature_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.private_feature_dbxref_feature_dbxref_id_seq OWNER TO postgres;

ALTER SEQUENCE private_feature_dbxref_feature_dbxref_id_seq OWNED BY private_feature_dbxref.feature_dbxref_id;

ALTER TABLE ONLY private_feature_dbxref ALTER COLUMN feature_dbxref_id SET DEFAULT nextval('private_feature_dbxref_feature_dbxref_id_seq'::regclass);

ALTER TABLE ONLY private_feature_dbxref
    ADD CONSTRAINT private_feature_dbxref_pkey PRIMARY KEY (feature_dbxref_id);


--
-- foreign keys
--
ALTER TABLE ONLY private_feature_dbxref
    ADD CONSTRAINT private_feature_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_feature_dbxref
    ADD CONSTRAINT private_feature_dbxref_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- constraints
--
ALTER TABLE ONLY private_feature_dbxref
    ADD CONSTRAINT private_feature_dbxref_c1 UNIQUE (feature_id, dbxref_id);


--
-- Indices 
--
CREATE INDEX private_feature_dbxref_idx1 ON private_feature_dbxref USING btree (feature_id);
CREATE INDEX private_feature_dbxref_idx2 ON private_feature_dbxref USING btree (dbxref_id);

COMMIT;

BEGIN;

-----------------------------------------------------------------------------
--
-- Name: pripub_feature_relationship; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--
CREATE TABLE pripub_feature_relationship (
    feature_relationship_id integer NOT NULL,
    subject_id integer NOT NULL,
    object_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.pripub_feature_relationship OWNER TO postgres;

COMMENT ON TABLE pripub_feature_relationship IS 'A mirror of the feature_relationship table.
 Only difference is that this table maps subject features in the private_feature table to object features in the feature table.  See
comments on feature_relationship table for more information.';


--
-- primary key
--
CREATE SEQUENCE pripub_feature_relationship_feature_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pripub_feature_relationship_feature_relationship_id_seq OWNER TO postgres;

ALTER SEQUENCE pripub_feature_relationship_feature_relationship_id_seq OWNED BY pripub_feature_relationship.feature_relationship_id;

ALTER TABLE ONLY pripub_feature_relationship ALTER COLUMN feature_relationship_id SET DEFAULT nextval('pripub_feature_relationship_feature_relationship_id_seq'::regclass);

ALTER TABLE ONLY pripub_feature_relationship
    ADD CONSTRAINT pripub_feature_relationship_pkey PRIMARY KEY (feature_relationship_id);


--
-- foreign keys
--
ALTER TABLE ONLY pripub_feature_relationship
    ADD CONSTRAINT pripub_feature_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY pripub_feature_relationship
    ADD CONSTRAINT pripub_feature_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY pripub_feature_relationship
    ADD CONSTRAINT pripub_feature_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- constraints
--
ALTER TABLE ONLY pripub_feature_relationship
    ADD CONSTRAINT pripub_feature_relationship_c1 UNIQUE (subject_id, object_id, type_id, rank);


--
-- Indices 
--
CREATE INDEX pripub_feature_relationship_idx1 ON pripub_feature_relationship USING btree (subject_id);

CREATE INDEX pripub_feature_relationship_idx2 ON pripub_feature_relationship USING btree (object_id);

CREATE INDEX pripub_feature_relationship_idx3 ON pripub_feature_relationship USING btree (type_id);

-----------------------------------------------------------------------------
--
-- Name: pubpri_feature_relationship; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--
CREATE TABLE pubpri_feature_relationship (
    feature_relationship_id integer NOT NULL,
    subject_id integer NOT NULL,
    object_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.pubpri_feature_relationship OWNER TO postgres;

COMMENT ON TABLE pubpri_feature_relationship IS 'A mirror of the feature_relationship table.
 Only difference is that this table maps subject features in the feature table to object features in the private_feature table.  See
comments on feature_relationship table for more information.';


--
-- primary key
--
CREATE SEQUENCE pubpri_feature_relationship_feature_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pubpri_feature_relationship_feature_relationship_id_seq OWNER TO postgres;

ALTER SEQUENCE pubpri_feature_relationship_feature_relationship_id_seq OWNED BY pubpri_feature_relationship.feature_relationship_id;

ALTER TABLE ONLY pubpri_feature_relationship ALTER COLUMN feature_relationship_id SET DEFAULT nextval('pubpri_feature_relationship_feature_relationship_id_seq'::regclass);

ALTER TABLE ONLY pubpri_feature_relationship
    ADD CONSTRAINT pubpri_feature_relationship_pkey PRIMARY KEY (feature_relationship_id);


--
-- foreign keys
--
ALTER TABLE ONLY pubpri_feature_relationship
    ADD CONSTRAINT pubpri_feature_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY pubpri_feature_relationship
    ADD CONSTRAINT pubpri_feature_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY pubpri_feature_relationship
    ADD CONSTRAINT pubpri_feature_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- constraints
--
ALTER TABLE ONLY pubpri_feature_relationship
    ADD CONSTRAINT pubpri_feature_relationship_c1 UNIQUE (subject_id, object_id, type_id, rank);


--
-- Indices 
--
CREATE INDEX pubpri_feature_relationship_idx1 ON pubpri_feature_relationship USING btree (subject_id);

CREATE INDEX pubpri_feature_relationship_idx2 ON pubpri_feature_relationship USING btree (object_id);

CREATE INDEX pubpri_feature_relationship_idx3 ON pubpri_feature_relationship USING btree (type_id);


COMMIT;









