BEGIN;

--
-- SQL for creating additional table for storing genome feature groups
--

SET search_path = public, pg_catalog;
SET default_tablespace = '';


-----------------------------------------------------------------------------
--
-- Table Name: group_category; Schema: public;  
--

CREATE TABLE group_category (
	group_category_id integer NOT NULL,
	name character varying(200) NOT NULL,
	description text DEFAULT NULL,
	username character varying(20) NOT NULL,
	standard boolean DEFAULT FALSE
);

--
-- primary key
--
CREATE SEQUENCE group_category_group_category_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER SEQUENCE group_category_group_category_id_seq OWNED BY group_category.group_category_id;

ALTER TABLE ONLY group_category ALTER COLUMN group_category_id SET DEFAULT nextval('group_category_group_category_id_seq'::regclass);

ALTER TABLE ONLY group_category
	ADD CONSTRAINT group_category_pkey PRIMARY KEY (group_category_id);

--
-- Constraints
--  
ALTER TABLE ONLY group_category
    ADD CONSTRAINT group_category_c1 UNIQUE (username, name);


-----------------------------------------------------------------------------
--
-- Table Name: genome_group; Schema: public;  
--

CREATE TABLE genome_group (
	genome_group_id integer NOT NULL,
	name character varying(200) NOT NULL,
	description text DEFAULT NULL,
	username character varying(20) NOT NULL,
	category_id integer,
	standard boolean DEFAULT FALSE,
	standard_value text DEFAULT NULL
);

--
-- primary key
--
CREATE SEQUENCE genome_group_genome_group_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER SEQUENCE genome_group_genome_group_id_seq OWNED BY genome_group.genome_group_id;

ALTER TABLE ONLY genome_group ALTER COLUMN genome_group_id SET DEFAULT nextval('genome_group_genome_group_id_seq'::regclass);

ALTER TABLE ONLY genome_group
	ADD CONSTRAINT genome_group_pkey PRIMARY KEY (genome_group_id);

--
-- foreign keys
--
ALTER TABLE ONLY genome_group
	ADD CONSTRAINT genome_group_category_id_fkey FOREIGN KEY (category_id) REFERENCES group_category(group_category_id);


--
-- Constraints
--  
ALTER TABLE ONLY genome_group
    ADD CONSTRAINT genome_group_c1 UNIQUE (username, name);


--
-- Indices
-- 
CREATE INDEX genome_group_idx1 ON genome_group USING btree (standard_value);


-----------------------------------------------------------------------------
--
-- Table Name: feature_group; Schema: public;  
--

CREATE TABLE feature_group (
	feature_group_id    integer NOT NULL,
	feature_id          integer NOT NULL,
	genome_group_id     integer NOT NULL,
	featureprop_id      integer
);

--
-- primary key
--
CREATE SEQUENCE feature_group_feature_group_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER SEQUENCE feature_group_feature_group_id_seq OWNED BY feature_group.feature_group_id;

ALTER TABLE ONLY feature_group ALTER COLUMN feature_group_id SET DEFAULT nextval('feature_group_feature_group_id_seq'::regclass);

ALTER TABLE ONLY feature_group
	ADD CONSTRAINT feature_group_pkey PRIMARY KEY (feature_group_id);

--
-- foreign keys
--
ALTER TABLE ONLY feature_group
	ADD CONSTRAINT feature_group_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY feature_group
	ADD CONSTRAINT feature_group_genome_group_id_fkey FOREIGN KEY (genome_group_id) REFERENCES genome_group(genome_group_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY feature_group
	ADD CONSTRAINT feature_group_featureprop_id_fkey FOREIGN KEY (featureprop_id) REFERENCES featureprop(featureprop_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

--
-- Constraints
--
ALTER TABLE ONLY feature_group
    ADD CONSTRAINT feature_group_c1 UNIQUE (feature_id, genome_group_id);

--
-- Indices
--
CREATE INDEX feature_group_idx1 ON feature_group USING btree (featureprop_id);


-----------------------------------------------------------------------------
--
-- Table Name: private_feature_group; Schema: public;  
--

CREATE TABLE private_feature_group (
	feature_group_id    integer NOT NULL,
	feature_id          integer NOT NULL,
	genome_group_id     integer NOT NULL,
	featureprop_id      integer
);

--
-- primary key
--
CREATE SEQUENCE private_feature_group_feature_group_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER SEQUENCE private_feature_group_feature_group_id_seq OWNED BY private_feature_group.feature_group_id;

ALTER TABLE ONLY private_feature_group ALTER COLUMN feature_group_id SET DEFAULT nextval('private_feature_group_feature_group_id_seq'::regclass);

ALTER TABLE ONLY private_feature_group
	ADD CONSTRAINT private_feature_group_pkey PRIMARY KEY (feature_group_id);

--
-- foreign keys
--
ALTER TABLE ONLY private_feature_group
	ADD CONSTRAINT private_feature_group_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_feature_group
	ADD CONSTRAINT private_feature_group_genome_group_id_fkey FOREIGN KEY (genome_group_id) REFERENCES genome_group(genome_group_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_feature_group
	ADD CONSTRAINT feature_group_featureprop_id_fkey FOREIGN KEY (featureprop_id) REFERENCES private_featureprop(featureprop_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Constraints
--
ALTER TABLE ONLY private_feature_group
    ADD CONSTRAINT private_feature_group_c1 UNIQUE (feature_id, genome_group_id);


--
-- Indices
--
CREATE INDEX private_feature_group_idx1 ON private_feature_group USING btree (featureprop_id);



COMMIT;
