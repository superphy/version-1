BEGIN;

--
-- SQL for creating tables to map features and trees
--

SET search_path = public, pg_catalog;
SET default_tablespace = '';

CREATE TYPE tree_relationship_type AS ENUM ('locus','allele','undefined');

-----------------------------------------------------------------------------
--
-- Name: feature_tree; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--
CREATE TABLE feature_tree (
    feature_tree_id integer NOT NULL,
    feature_id integer NOT NULL,
    tree_id integer NOT NULL,
    tree_relationship tree_relationship_type NOT NULL DEFAULT 'undefined'
);


ALTER TABLE public.feature_tree OWNER TO postgres;

COMMENT ON TABLE feature_tree IS 'Maps features to the trees structures. When tree_relationship_type is locus
that feature was used as a query gene to find other sequences to build the tree. When tree_relationship_type is allele,
that sequence was used to build the tree. (note: the containing contig_collection feature_id will appear as the tree node, so that mapping
of global genome properties can happen quickly).';


--
-- primary key
--
CREATE SEQUENCE feature_tree_feature_tree_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.feature_tree_feature_tree_id_seq OWNER TO postgres;

ALTER SEQUENCE feature_tree_feature_tree_id_seq OWNED BY feature_tree.feature_tree_id;

ALTER TABLE ONLY feature_tree ALTER COLUMN feature_tree_id SET DEFAULT nextval('feature_tree_feature_tree_id_seq'::regclass);

ALTER TABLE ONLY feature_tree
    ADD CONSTRAINT feature_tree_pkey PRIMARY KEY (feature_tree_id);


--
-- foreign keys
--
ALTER TABLE ONLY feature_tree
    ADD CONSTRAINT feature_tree_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY feature_tree
    ADD CONSTRAINT feature_tree_tree_id_fkey FOREIGN KEY (tree_id) REFERENCES tree(tree_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

--
-- constraints
--
ALTER TABLE ONLY feature_tree
    ADD CONSTRAINT feature_tree_c1 UNIQUE (feature_id, tree_id);


--
-- Indices 
--
CREATE INDEX feature_tree_idx1 ON feature_tree USING btree (feature_id);

CREATE INDEX feature_tree_idx2 ON feature_tree USING btree (tree_id);


-----------------------------------------------------------------------------
--
-- Name: private_feature_tree; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--
CREATE TABLE private_feature_tree (
    feature_tree_id integer NOT NULL,
    feature_id integer NOT NULL,
    tree_id integer NOT NULL,
    tree_relationship tree_relationship_type NOT NULL DEFAULT 'undefined'
);


ALTER TABLE public.private_feature_tree OWNER TO postgres;

COMMENT ON TABLE private_feature_tree IS 'Maps private features to the trees structures. When tree_relationship_type is locus
that feature was used as a query gene to find other sequences to build the tree. When tree_relationship_type is allele,
that sequence was used to build the tree. (note: the containing contig_collection feature_id will appear as the tree node, so that mapping
of global genome properties can happen quickly).';


--
-- primary key
--
CREATE SEQUENCE private_feature_tree_feature_tree_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public .private_feature_tree_feature_tree_id_seq OWNER TO postgres;

ALTER SEQUENCE private_feature_tree_feature_tree_id_seq OWNED BY private_feature_tree.feature_tree_id;

ALTER TABLE ONLY private_feature_tree ALTER COLUMN feature_tree_id SET DEFAULT nextval('private_feature_tree_feature_tree_id_seq'::regclass);

ALTER TABLE ONLY private_feature_tree
    ADD CONSTRAINT private_feature_tree_pkey PRIMARY KEY (feature_tree_id);


--
-- foreign keys
--
ALTER TABLE ONLY private_feature_tree
    ADD CONSTRAINT private_feature_tree_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY private_feature_tree
    ADD CONSTRAINT private_feature_tree_tree_id_fkey FOREIGN KEY (tree_id) REFERENCES tree(tree_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

--
-- constraints
--
ALTER TABLE ONLY private_feature_tree
    ADD CONSTRAINT private_feature_tree_c1 UNIQUE (feature_id, tree_id);


--
-- Indices 
--
CREATE INDEX private_feature_tree_idx1 ON private_feature_tree USING btree (feature_id);

CREATE INDEX private_feature_tree_idx2 ON private_feature_tree USING btree (tree_id);

COMMIT;

