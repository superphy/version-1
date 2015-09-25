BEGIN;

--
-- SQL for creating additional table for storing private/public snps
--

SET search_path = public, pg_catalog;
SET default_tablespace = '';


-----------------------------------------------------------------------------
--
-- Table Name: snp_core; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE snp_core (
	snp_core_id         integer NOT NULL,
	pangenome_region_id integer NOT NULL,
	allele              char(1) NOT NULL DEFAULT 'n',
	position            integer NOT NULL DEFAULT -1,
	gap_offset          integer NOT NULL DEFAULT 0,
	aln_column          integer DEFAULT NULL,
    frequency_a         integer DEFAULT 0,
    frequency_t         integer DEFAULT 0,
    frequency_c         integer DEFAULT 0,
    frequency_g         integer DEFAULT 0,
    frequency_gap       integer DEFAULT 0,
    frequency_other     integer DEFAULT 0
);

ALTER TABLE public.snp_core OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE snp_core_snp_core_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.snp_core_snp_core_id_seq OWNER TO genodo;

ALTER SEQUENCE snp_core_snp_core_id_seq OWNED BY snp_core.snp_core_id;

ALTER TABLE ONLY snp_core ALTER COLUMN snp_core_id SET DEFAULT nextval('snp_core_snp_core_id_seq'::regclass);

ALTER TABLE ONLY snp_core
	ADD CONSTRAINT snp_core_pkey PRIMARY KEY (snp_core_id);

--
-- foreign keys
--
ALTER TABLE ONLY snp_core
	ADD CONSTRAINT snp_core_pangenome_region_id_fkey FOREIGN KEY (pangenome_region_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

--
-- Constraints
--
ALTER TABLE ONLY snp_core
    ADD CONSTRAINT snp_core_c1 UNIQUE (pangenome_region_id, position, gap_offset);

--
-- Indices
--
CREATE INDEX snp_core_idx1 ON snp_core USING btree (aln_column);

--
-- Utility function - returns boolean indicating if allele frequency is valid SNP
--   rather than potential SNP.
--
-- USAGE: SELECT snp_core.is_polymorphism FROM snp_core;
--

CREATE OR REPLACE FUNCTION is_polymorphism(rec snp_core)
  RETURNS boolean
AS $$
DECLARE
    states integer := 0;
BEGIN
	IF $1.allele = 'A' OR $1.allele = 'T' OR $1.allele = 'G' OR $1.allele = 'C' THEN
		states = states + 1;
	END IF;

	IF $1.frequency_a >= 1 AND $1.allele != 'A' THEN
		states = states + 1;
	END IF;

	IF $1.frequency_t >= 1 AND $1.allele != 'T' THEN
		states = states + 1;
	END IF;

	IF $1.frequency_g >= 1 AND $1.allele != 'G' THEN
		states = states + 1;
	END IF;

	IF $1.frequency_c >= 1 AND $1.allele != 'C' THEN
		states = states + 1;
	END IF;
	
	IF states > 1 THEN 
		RETURN TRUE;
    ELSE
    	RETURN FALSE;
 	END IF;
    
END
$$
IMMUTABLE
LANGUAGE 'plpgsql';


-----------------------------------------------------------------------------
--
-- Table Name: snp_variation; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE snp_variation (
	snp_variation_id integer NOT NULL,
	snp_id           integer NOT NULL,
	contig_collection_id integer NOT NULL,
	contig_id           integer NOT NULL,
	locus_id            integer NOT NULL,
	allele           char(1) NOT NULL DEFAULT 'n'
);

ALTER TABLE public.snp_variation OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE snp_variation_snp_variation_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.snp_variation_snp_variation_id_seq OWNER TO genodo;

ALTER SEQUENCE snp_variation_snp_variation_id_seq OWNED BY snp_variation.snp_variation_id;

ALTER TABLE ONLY snp_variation ALTER COLUMN snp_variation_id SET DEFAULT nextval('snp_variation_snp_variation_id_seq'::regclass);

ALTER TABLE ONLY snp_variation
	ADD CONSTRAINT snp_variation_pkey PRIMARY KEY (snp_variation_id);

--
-- Foreign keys
--
ALTER TABLE ONLY snp_variation
	ADD CONSTRAINT snp_variation_snp_id_fkey FOREIGN KEY (snp_id) REFERENCES snp_core(snp_core_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY snp_variation
	ADD CONSTRAINT snp_variation_contig_collection_id_fkey FOREIGN KEY (contig_collection_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY snp_variation
	ADD CONSTRAINT snp_variation_contig_id_fkey FOREIGN KEY (contig_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY snp_variation
	ADD CONSTRAINT snp_variation_locus_id_fkey FOREIGN KEY (locus_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Constraints
--  
ALTER TABLE ONLY snp_variation
    ADD CONSTRAINT snp_variation_c1 UNIQUE (snp_id, contig_collection_id);

--
-- Indices
--
CREATE INDEX snp_variation_idx1 ON snp_variation USING btree (snp_id);

CREATE INDEX snp_variation_idx2 ON snp_variation USING btree (contig_collection_id);



-----------------------------------------------------------------------------
--
-- Table Name: private_snp_variation; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE private_snp_variation (
	snp_variation_id integer NOT NULL,
	snp_id           integer NOT NULL,
	contig_collection_id integer NOT NULL,
	contig_id        integer NOT NULL,
	locus_id         integer NOT NULL,
	allele           char(1) NOT NULL DEFAULT 'n'
);

ALTER TABLE public.private_snp_variation OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE private_snp_variation_snp_variation_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.private_snp_variation_snp_variation_id_seq OWNER TO genodo;

ALTER SEQUENCE private_snp_variation_snp_variation_id_seq OWNED BY private_snp_variation.snp_variation_id;

ALTER TABLE ONLY private_snp_variation ALTER COLUMN snp_variation_id SET DEFAULT nextval('private_snp_variation_snp_variation_id_seq'::regclass);

ALTER TABLE ONLY private_snp_variation
	ADD CONSTRAINT private_snp_variation_pkey PRIMARY KEY (snp_variation_id);

--
-- Foreign keys
--
ALTER TABLE ONLY private_snp_variation
	ADD CONSTRAINT private_snp_variation_snp_id_fkey FOREIGN KEY (snp_id) REFERENCES snp_core(snp_core_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_snp_variation
	ADD CONSTRAINT private_snp_variation_contig_collection_id_fkey FOREIGN KEY (contig_collection_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_snp_variation
	ADD CONSTRAINT private_snp_variation_contig_id_fkey FOREIGN KEY (contig_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_snp_variation
	ADD CONSTRAINT private_snp_variation_locus_id_fkey FOREIGN KEY (locus_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Constraints
--
ALTER TABLE ONLY private_snp_variation
    ADD CONSTRAINT private_snp_variation_c1 UNIQUE (snp_id, contig_collection_id);

--
-- Indices
--
CREATE INDEX private_snp_variation_idx1 ON private_snp_variation USING btree (snp_id);

CREATE INDEX private_snp_variation_idx2 ON private_snp_variation USING btree (contig_collection_id);

-----------------------------------------------------------------------------
--
-- Table Name: snp_alignment; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE snp_alignment (
	snp_alignment_id integer NOT NULL,
	name character varying(100),
	aln_column integer NOT NULL,
	alignment text
);

ALTER TABLE public.snp_alignment OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE snp_alignment_snp_alignment_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.snp_alignment_snp_alignment_id_seq OWNER TO genodo;

ALTER SEQUENCE snp_alignment_snp_alignment_id_seq OWNED BY snp_alignment.snp_alignment_id;

ALTER TABLE ONLY snp_alignment ALTER COLUMN snp_alignment_id SET DEFAULT nextval('snp_alignment_snp_alignment_id_seq'::regclass);

ALTER TABLE ONLY snp_alignment
	ADD CONSTRAINT snp_alignment_pkey PRIMARY KEY (snp_alignment_id);


--
-- Constraints
--
ALTER TABLE ONLY snp_alignment
    ADD CONSTRAINT snp_alignment_c1 UNIQUE (name);


COMMIT;

BEGIN;

-----------------------------------------------------------------------------
--
-- Table Name: snp_position; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE snp_position (
	snp_position_id        integer NOT NULL,
	contig_collection_id   integer NOT NULL,
	contig_id              integer NOT NULL,
    pangenome_region_id    integer NOT NULL,
	locus_id               integer NOT NULL,
    region_start           integer,
    locus_start            integer,
    region_end             integer,
    locus_end              integer,
    locus_gap_offset       integer DEFAULT -1
);

ALTER TABLE public.snp_position OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE snp_position_snp_position_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.snp_position_snp_position_id_seq OWNER TO genodo;

ALTER SEQUENCE snp_position_snp_position_id_seq OWNED BY snp_position.snp_position_id;

ALTER TABLE ONLY snp_position ALTER COLUMN snp_position_id SET DEFAULT nextval('snp_position_snp_position_id_seq'::regclass);

ALTER TABLE ONLY snp_position
	ADD CONSTRAINT snp_position_pkey PRIMARY KEY (snp_position_id);

--
-- Foreign keys
--
ALTER TABLE ONLY snp_position
	ADD CONSTRAINT snp_position_contig_collection_id_fkey FOREIGN KEY (contig_collection_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY snp_position
	ADD CONSTRAINT snp_position_contig_id_fkey FOREIGN KEY (contig_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY snp_position
	ADD CONSTRAINT snp_position_locus_id_fkey FOREIGN KEY (locus_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY snp_position
	ADD CONSTRAINT snp_position_pangenome_region_id_fkey FOREIGN KEY (pangenome_region_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Constraints
--  
ALTER TABLE ONLY snp_position
    ADD CONSTRAINT snp_position_c1 UNIQUE (contig_collection_id, pangenome_region_id, region_start, region_end);

ALTER TABLE ONLY snp_position
    ADD CONSTRAINT snp_position_c2 UNIQUE (locus_id, region_start, region_end);

--
-- Indices
--

-----------------------------------------------------------------------------
--
-- Table Name: private_snp_position; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE private_snp_position (
	snp_position_id        integer NOT NULL,
	contig_collection_id   integer NOT NULL,
	contig_id              integer NOT NULL,
        pangenome_region_id    integer NOT NULL,
	locus_id               integer NOT NULL,
        region_start           integer,
        locus_start            integer,
        region_end             integer,
        locus_end              integer,
        locus_gap_offset       integer DEFAULT -1
);

ALTER TABLE public.private_snp_position OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE private_snp_position_snp_position_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.private_snp_position_snp_position_id_seq OWNER TO genodo;

ALTER SEQUENCE private_snp_position_snp_position_id_seq OWNED BY private_snp_position.snp_position_id;

ALTER TABLE ONLY private_snp_position ALTER COLUMN snp_position_id SET DEFAULT nextval('private_snp_position_snp_position_id_seq'::regclass);

ALTER TABLE ONLY private_snp_position
	ADD CONSTRAINT private_snp_position_pkey PRIMARY KEY (snp_position_id);

--
-- Foreign keys
--
ALTER TABLE ONLY private_snp_position
	ADD CONSTRAINT private_snp_position_contig_collection_id_fkey FOREIGN KEY (contig_collection_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_snp_position
	ADD CONSTRAINT private_snp_position_contig_id_fkey FOREIGN KEY (contig_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_snp_position
	ADD CONSTRAINT private_snp_position_locus_id_fkey FOREIGN KEY (locus_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_snp_position
	ADD CONSTRAINT private_snp_position_pangenome_region_id_fkey FOREIGN KEY (pangenome_region_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;



--
-- Constraints
--  
ALTER TABLE ONLY private_snp_position
    ADD CONSTRAINT private_snp_position_c1 UNIQUE (contig_collection_id, pangenome_region_id, region_start, region_end);

ALTER TABLE ONLY private_snp_position
    ADD CONSTRAINT private_snp_position_c2 UNIQUE (locus_id, region_start, region_end);

--
-- Indices
--

-----------------------------------------------------------------------------
--
-- Table Name: gap_position; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE gap_position (
	gap_position_id        integer NOT NULL,
	contig_collection_id   integer NOT NULL,
	contig_id              integer NOT NULL,
    pangenome_region_id    integer NOT NULL,
	locus_id               integer NOT NULL,
	snp_id                 integer NOT NULL,
    locus_pos              integer NOT NULL,
    locus_gap_offset       integer DEFAULT -1
);

ALTER TABLE public.gap_position OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE gap_position_gap_position_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.gap_position_gap_position_id_seq OWNER TO genodo;

ALTER SEQUENCE gap_position_gap_position_id_seq OWNED BY gap_position.gap_position_id;

ALTER TABLE ONLY gap_position ALTER COLUMN gap_position_id SET DEFAULT nextval('gap_position_gap_position_id_seq'::regclass);

ALTER TABLE ONLY gap_position
	ADD CONSTRAINT gap_position_pkey PRIMARY KEY (gap_position_id);

--
-- Foreign keys
--
ALTER TABLE ONLY gap_position
	ADD CONSTRAINT gap_position_contig_collection_id_fkey FOREIGN KEY (contig_collection_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY gap_position
	ADD CONSTRAINT gap_position_contig_id_fkey FOREIGN KEY (contig_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY gap_position
	ADD CONSTRAINT gap_position_locus_id_fkey FOREIGN KEY (locus_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY gap_position
	ADD CONSTRAINT gap_position_pangenome_region_id_fkey FOREIGN KEY (pangenome_region_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY gap_position
	ADD CONSTRAINT gap_position_snp_id_fkey FOREIGN KEY (snp_id) REFERENCES snp_core(snp_core_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Constraints
--  
ALTER TABLE ONLY gap_position
    ADD CONSTRAINT gap_position_c1 UNIQUE (snp_id, contig_collection_id);

ALTER TABLE ONLY gap_position
    ADD CONSTRAINT gap_position_c2 UNIQUE (snp_id, locus_id);

--
-- Indices
--

-----------------------------------------------------------------------------
--
-- Table Name: private_gap_position; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE private_gap_position (
	gap_position_id        integer NOT NULL,
	contig_collection_id   integer NOT NULL,
	contig_id              integer NOT NULL,
    pangenome_region_id    integer NOT NULL,
	locus_id               integer NOT NULL,
	snp_id                 integer NOT NULL,
    locus_pos              integer NOT NULL,
    locus_gap_offset       integer DEFAULT -1
);

ALTER TABLE public.private_gap_position OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE private_gap_position_gap_position_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.private_gap_position_gap_position_id_seq OWNER TO genodo;

ALTER SEQUENCE private_gap_position_gap_position_id_seq OWNED BY private_gap_position.gap_position_id;

ALTER TABLE ONLY private_gap_position ALTER COLUMN gap_position_id SET DEFAULT nextval('private_gap_position_gap_position_id_seq'::regclass);

ALTER TABLE ONLY private_gap_position
	ADD CONSTRAINT private_gap_position_pkey PRIMARY KEY (gap_position_id);

--
-- Foreign keys
--
ALTER TABLE ONLY private_gap_position
	ADD CONSTRAINT private_gap_position_contig_collection_id_fkey FOREIGN KEY (contig_collection_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_gap_position
	ADD CONSTRAINT private_gap_position_contig_id_fkey FOREIGN KEY (contig_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_gap_position
	ADD CONSTRAINT private_gap_position_locus_id_fkey FOREIGN KEY (locus_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_gap_position
	ADD CONSTRAINT private_gap_position_pangenome_region_id_fkey FOREIGN KEY (pangenome_region_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_gap_position
	ADD CONSTRAINT private_gap_position_snp_id_fkey FOREIGN KEY (snp_id) REFERENCES snp_core(snp_core_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Constraints
--  
ALTER TABLE ONLY private_gap_position
    ADD CONSTRAINT private_gap_position_c1 UNIQUE (snp_id, contig_collection_id);

ALTER TABLE ONLY private_gap_position
    ADD CONSTRAINT private_gap_position_c2 UNIQUE (snp_id, locus_id);

--
-- Indices
--


COMMIT;
