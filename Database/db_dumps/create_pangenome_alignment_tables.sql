BEGIN;

--
-- SQL for creating additional tables for storing both core and accessory pangenome presence / absence strings
--

SET search_path = public, pg_catalog;
SET default_tablespace = '';


-----------------------------------------------------------------------------
--
-- Table Name: core_region; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE core_region (
	core_region_id         integer NOT NULL,
	pangenome_region_id    integer NOT NULL,
	aln_column             integer NOT NULL DEFAULT 0
);

ALTER TABLE public.core_region OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE core_region_core_region_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.core_region_core_region_id_seq OWNER TO genodo;

ALTER SEQUENCE core_region_core_region_id_seq OWNED BY core_region.core_region_id;

ALTER TABLE ONLY core_region ALTER COLUMN core_region_id SET DEFAULT nextval('core_region_core_region_id_seq'::regclass);

ALTER TABLE ONLY core_region
	ADD CONSTRAINT core_region_pkey PRIMARY KEY (core_region_id);

--
-- foreign keys
--
ALTER TABLE ONLY core_region
	ADD CONSTRAINT core_region_pangenome_region_id_fkey FOREIGN KEY (pangenome_region_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

--
-- Constraints
--
ALTER TABLE ONLY core_region
    ADD CONSTRAINT core_region_c1 UNIQUE (pangenome_region_id);

ALTER TABLE ONLY core_region
    ADD CONSTRAINT core_region_c2 UNIQUE (aln_column);


--
-- Indices
--



-----------------------------------------------------------------------------
--
-- Table Name: pangenome_alignment; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE pangenome_alignment (
	pangenome_alignment_id integer NOT NULL,
	name character varying(100),
	core_column integer NOT NULL,
	core_alignment text,
    acc_column integer NOT NULL,
	acc_alignment text
);

ALTER TABLE public.pangenome_alignment OWNER TO genodo;
COMMENT ON TABLE pangenome_alignment IS 'The pangenome_alignment table contains both the core and accessory pangenome region aligned prensence/absence strings in column core_alignment and acc_alignment respectively.';

--
-- primary key
--
CREATE SEQUENCE pangenome_alignment_pangenome_alignment_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.pangenome_alignment_pangenome_alignment_id_seq OWNER TO genodo;

ALTER SEQUENCE pangenome_alignment_pangenome_alignment_id_seq OWNED BY pangenome_alignment.pangenome_alignment_id;

ALTER TABLE ONLY pangenome_alignment ALTER COLUMN pangenome_alignment_id SET DEFAULT nextval('pangenome_alignment_pangenome_alignment_id_seq'::regclass);

ALTER TABLE ONLY pangenome_alignment
	ADD CONSTRAINT pangenome_alignment_pkey PRIMARY KEY (pangenome_alignment_id);


--
-- Constraints
--
ALTER TABLE ONLY pangenome_alignment
    ADD CONSTRAINT pangenome_alignment_c1 UNIQUE (name);


-----------------------------------------------------------------------------
--
-- Table Name: accessory_region; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE accessory_region (
	accessory_region_id         integer NOT NULL,
	pangenome_region_id    integer NOT NULL,
	aln_column             integer NOT NULL DEFAULT 0
);

ALTER TABLE public.accessory_region OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE accessory_region_accessory_region_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.accessory_region_accessory_region_id_seq OWNER TO genodo;

ALTER SEQUENCE accessory_region_accessory_region_id_seq OWNED BY accessory_region.accessory_region_id;

ALTER TABLE ONLY accessory_region ALTER COLUMN accessory_region_id SET DEFAULT nextval('accessory_region_accessory_region_id_seq'::regclass);

ALTER TABLE ONLY accessory_region
	ADD CONSTRAINT accessory_region_pkey PRIMARY KEY (accessory_region_id);

--
-- foreign keys
--
ALTER TABLE ONLY accessory_region
	ADD CONSTRAINT accessory_region_pangenome_region_id_fkey FOREIGN KEY (pangenome_region_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

--
-- Constraints
--
ALTER TABLE ONLY accessory_region
    ADD CONSTRAINT accessory_region_c1 UNIQUE (pangenome_region_id);

ALTER TABLE ONLY accessory_region
    ADD CONSTRAINT accessory_region_c2 UNIQUE (aln_column);


--
-- Indices
--

COMMIT;

