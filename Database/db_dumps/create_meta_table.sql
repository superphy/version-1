--
-- SQL for creating additional tables for storing phylogenetic meta strings
--

SET search_path = public, pg_catalog;
SET default_tablespace = '';

--
-- Table Name: meta; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TYPE meta_type AS ENUM ('perl','json','undefined');

CREATE TABLE meta (
	meta_id          integer NOT NULL,
	name             varchar(10) NOT NULL,
	format           meta_type NOT NULL DEFAULT 'undefined',
	data_string      text NOT NULL,
	timelastmodified timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.meta OWNER TO postgres;

--
-- primary key
--
CREATE SEQUENCE meta_meta_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.meta_meta_id_seq OWNER TO postgres;

ALTER SEQUENCE meta_meta_id_seq OWNED BY meta.meta_id;

ALTER TABLE ONLY meta ALTER COLUMN meta_id SET DEFAULT nextval('meta_meta_id_seq'::regclass);

ALTER TABLE ONLY meta
	ADD CONSTRAINT meta_pkey PRIMARY KEY (meta_id);

--
-- Constraints
--
ALTER TABLE ONLY meta
	ADD CONSTRAINT meta_c1 UNIQUE (name);

COMMENT ON INDEX meta_c1 IS 'Each meta must have unique name.';

--
-- Indices 
--
