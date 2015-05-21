
BEGIN;

--
-- SQL for creating additional tables for hosts and associated sources
--

SET search_path = public, pg_catalog;
SET default_tablespace = '';

-----------------------------------------------------------------------------
--
-- Table Name: host_cateogry; Schema: public; Owner: genodo; ablespace: 
--

CREATE TABLE host_category (
	host_category_id integer NOT NULL,
	uniquename       varchar(20) NOT NULL,
	displayname      varchar(100) NOT NULL
);

ALTER TABLE public.host_category OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE host_category_host_category_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.host_category_host_category_id_seq OWNER TO genodo;

ALTER SEQUENCE host_category_host_category_id_seq OWNED BY host_category.host_category_id;

ALTER TABLE ONLY host_category ALTER COLUMN host_category_id SET DEFAULT nextval('host_category_host_category_id_seq'::regclass);

ALTER TABLE ONLY host_category
	ADD CONSTRAINT host_category_pkey PRIMARY KEY (host_category_id);

--
-- foreign keys
--

--
-- Constraints
--  
ALTER TABLE ONLY host_category
	ADD CONSTRAINT host_category_c1 UNIQUE (uniquename);

ALTER TABLE ONLY host_category
	ADD CONSTRAINT host_category_c2 UNIQUE (displayname);

--
-- Indices 
--


-----------------------------------------------------------------------------
--
-- Table Name: host; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE host (
	host_id          integer NOT NULL,
	host_category_id integer NOT NULL,
	uniquename       varchar(20) NOT NULL,
	displayname      varchar(100) NOT NULL,   
        commonname       varchar(100) NOT NULL,
        scientificname   varchar(100) NOT NULL
);

ALTER TABLE public.host OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE host_host_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.host_host_id_seq OWNER TO genodo;

ALTER SEQUENCE host_host_id_seq OWNED BY host.host_id;

ALTER TABLE ONLY host ALTER COLUMN host_id SET DEFAULT nextval('host_host_id_seq'::regclass);

ALTER TABLE ONLY host
	ADD CONSTRAINT host_pkey PRIMARY KEY (host_id);

--
-- foreign keys
--
ALTER TABLE ONLY host
	ADD CONSTRAINT host_host_category_id_fkey FOREIGN KEY (host_category_id) REFERENCES host_category(host_category_id);

--
-- Constraints
--  
ALTER TABLE ONLY host
	ADD CONSTRAINT host_c1 UNIQUE (uniquename);

ALTER TABLE ONLY host
	ADD CONSTRAINT host_c2 UNIQUE (displayname);

--
-- Indices 
--

-----------------------------------------------------------------------------
--
-- Table Name: source; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE source (
	source_id          integer NOT NULL,
	host_category_id integer NOT NULL,
	uniquename       varchar(20) NOT NULL,
	displayname      varchar(100) NOT NULL,
        description      text
);

ALTER TABLE public.source OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE source_source_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.source_source_id_seq OWNER TO genodo;

ALTER SEQUENCE source_source_id_seq OWNED BY source.source_id;

ALTER TABLE ONLY source ALTER COLUMN source_id SET DEFAULT nextval('source_source_id_seq'::regclass);

ALTER TABLE ONLY source
	ADD CONSTRAINT source_pkey PRIMARY KEY (source_id);

--
-- foreign keys
--
ALTER TABLE ONLY source
	ADD CONSTRAINT source_host_category_id_fkey FOREIGN KEY (host_category_id) REFERENCES host_category(host_category_id);

--
-- Constraints
--  
ALTER TABLE ONLY source
	ADD CONSTRAINT source_c1 UNIQUE (host_category_id, uniquename);

ALTER TABLE ONLY source
	ADD CONSTRAINT source_c2 UNIQUE (host_category_id, displayname);

--
-- Indices 
--

-----------------------------------------------------------------------------
--
-- Table Name: syndrome; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE syndrome (
	syndrome_id          integer NOT NULL,
	host_category_id integer NOT NULL,
	uniquename       varchar(20) NOT NULL,
	displayname      varchar(100) NOT NULL,
	description      text
);

ALTER TABLE public.syndrome OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE syndrome_syndrome_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.syndrome_syndrome_id_seq OWNER TO genodo;

ALTER SEQUENCE syndrome_syndrome_id_seq OWNED BY syndrome.syndrome_id;

ALTER TABLE ONLY syndrome ALTER COLUMN syndrome_id SET DEFAULT nextval('syndrome_syndrome_id_seq'::regclass);

ALTER TABLE ONLY syndrome
	ADD CONSTRAINT syndrome_pkey PRIMARY KEY (syndrome_id);

--
-- foreign keys
--
ALTER TABLE ONLY syndrome
	ADD CONSTRAINT syndrome_host_category_id_fkey FOREIGN KEY (host_category_id) REFERENCES host_category(host_category_id);

--
-- Constraints
--  
ALTER TABLE ONLY syndrome
	ADD CONSTRAINT syndrome_c1 UNIQUE (host_category_id, uniquename);

ALTER TABLE ONLY syndrome
	ADD CONSTRAINT syndrome_c2 UNIQUE (host_category_id, displayname);

--
-- Indices 
--


COMMIT;

BEGIN;

-----------------------------------------------------------------------------
--
-- Populate tables
--

--
-- Populate host_category
-- 
INSERT INTO host_category (uniquename, displayname) VALUES
	('human', 'Human'),
	('mammal', 'Non-human Mammalia'),
	('bird', 'Aves'),
	('env', 'Environmental Sources');


DO $$
DECLARE
	human_cat integer;
	mammal_cat integer;
	bird_cat integer;
	env_cat integer;
BEGIN

SELECT host_category_id INTO human_cat FROM host_category WHERE uniquename = 'human';
SELECT host_category_id INTO mammal_cat FROM host_category WHERE uniquename = 'mammal';
SELECT host_category_id INTO bird_cat FROM host_category WHERE uniquename = 'bird';
SELECT host_category_id INTO env_cat FROM host_category WHERE uniquename = 'env';


--
-- Populate host
--

INSERT INTO host (host_category_id, uniquename, displayname, commonname, scientificname) VALUES
	(human_cat, 'hsapiens', 'Homo sapiens (human)', 'human', 'Homo sapiens'),
	(mammal_cat, 'btaurus', 'Bos taurus (cow)', 'cow', 'Bos taurus'),
	(mammal_cat, 'sscrofa', 'Sus scrofa (pig)', 'pig', 'Sus scrofa'),
	(mammal_cat, 'mmusculus', 'Mus musculus (mouse)', 'mouse', 'Mus musculus'),
	(mammal_cat, 'oaries', 'Ovis aries (sheep)', 'sheep', 'Ovis aries'),
	(bird_cat, 'ggallus', 'Gallus gallus (chicken)', 'chicken', 'Gallus gallus'),
	(mammal_cat, 'ocuniculus', 'Oryctolagus cuniculus (rabbit)', 'rabbit', 'Oryctolagus cuniculus'),
	(mammal_cat, 'clupus', 'Canis lupus familiaris (dog)', 'dog', 'Canis lupus familiaris'),
	(mammal_cat, 'fcatus', 'Felis catus (cat)', 'cat', 'Felis catus'),
	(env_cat, 'environment', 'Environmental source', 'environment', 'Environmental source'),
	(mammal_cat, 'other', 'Other (fill in adjacent fields)', 'other', 'User-specified Host');
	

--
-- Populate source
--

INSERT INTO source (host_category_id, uniquename, displayname) VALUES
	(human_cat, 'stool', 'Stool'),
	(human_cat, 'urine', 'Urine'),
	(human_cat, 'colon', 'Colon'),
	(human_cat, 'ileum', 'Ileum'),
	(human_cat, 'cecum', 'Cecum'),
	(human_cat, 'intestine', 'Intestine'),
	(human_cat, 'blood', 'Blood'),
	(human_cat, 'liver', 'Liver'),
	(human_cat, 'cerebrospinal_fluid', 'cerebrospinal_fluid'),
	(human_cat, 'other', 'Other (fill in adjacent fields)'),
	(mammal_cat, 'feces', 'Feces'),
	(mammal_cat, 'urine', 'Urine'),
	(mammal_cat, 'meat', 'Meat'),
	(mammal_cat, 'blood', 'Blood'),
	(mammal_cat, 'liver', 'Liver'),
	(mammal_cat, 'intestine', 'Intestine'),
	(mammal_cat, 'other', 'Other (fill in adjacent fields)'),
	(bird_cat, 'feces', 'Feces'),
	(bird_cat, 'yolk', 'Yolk'),
	(bird_cat, 'meat', 'Meat'),
	(bird_cat, 'blood', 'Blood'),
	(bird_cat, 'liver', 'Liver'),
	(bird_cat, 'other', 'Other (fill in adjacent fields)'),
	(env_cat, 'veggiefood', 'Vegetable-based food'),
	(env_cat, 'meatfood', 'Meat-based food'),
	(env_cat, 'water', 'Water'),
	(env_cat, 'other', 'Other (fill in adjacent fields)');


--
-- Populate syndrome
--

INSERT INTO syndrome (host_category_id, uniquename, displayname) VALUES
	(human_cat, 'gastroenteritis', 'Gastroenteritis'),
	(human_cat, 'bloody_diarrhea', 'Bloody diarrhea'),
	(human_cat, 'hus', 'Hemolytic-uremic syndrome'),
	(human_cat, 'hc', 'Hemorrhagic colitis'),
	(human_cat, 'uti', 'Urinary tract infection (cystitis)'),
	(human_cat, 'crohns', E'Crohn\'s Disease'),
	(human_cat, 'uc', 'Ulcerateive colitis'),
	(human_cat, 'meningitis', 'Meningitis'),
	(human_cat, 'pneumonia', 'Pneumonia'),
	(human_cat, 'pyelonephritis', 'Pyelonephritis'),
	(human_cat, 'bacteriuria', 'Bacteriuria'),
	(mammal_cat, 'pneumonia', 'Pneumonia'),
	(mammal_cat, 'diarrhea', 'Diarrhea'),
	(mammal_cat, 'septicaemia', 'Septicaemia'),
	(mammal_cat, 'mastitis', 'Mastitis'),
	(mammal_cat, 'peritonitis', 'Peritonitis'),
	(bird_cat, 'pneumonia', 'Pneumonia'),
	(bird_cat, 'diarrhea', 'Diarrhea'),
	(bird_cat, 'septicaemia', 'Septicaemia'),
	(bird_cat, 'peritonitis', 'Peritonitis');	


END $$;

COMMIT;

