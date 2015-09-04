--
-- SQL for creating additional tables for storing phylogenetic tree strings
--

SET search_path = public, pg_catalog;
SET default_tablespace = '';

--
-- Table Name: tree; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TYPE tree_type AS ENUM ('perl','json','newick','undefined');

CREATE TABLE tree (
	tree_id          integer NOT NULL,
	name             varchar(10) NOT NULL,
	format           tree_type NOT NULL DEFAULT 'undefined',
	tree_string      text NOT NULL,
	timelastmodified timestamp without time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.tree OWNER TO postgres;

--
-- primary key
--
CREATE SEQUENCE tree_tree_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.tree_tree_id_seq OWNER TO postgres;

ALTER SEQUENCE tree_tree_id_seq OWNED BY tree.tree_id;

ALTER TABLE ONLY tree ALTER COLUMN tree_id SET DEFAULT nextval('tree_tree_id_seq'::regclass);

ALTER TABLE ONLY tree
	ADD CONSTRAINT tree_pkey PRIMARY KEY (tree_id);

--
-- Constraints
--
ALTER TABLE ONLY tree
	ADD CONSTRAINT tree_c1 UNIQUE (name);

COMMENT ON INDEX tree_c1 IS 'Each tree must have unique name.';

--
-- Indices 
--
