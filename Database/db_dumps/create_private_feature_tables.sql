BEGIN;

--
-- SQL for creating additional tables for related feature data for private genomes
--

--
-- Name: private_featureloc; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE private_featureloc (
    featureloc_id integer NOT NULL,
    feature_id integer NOT NULL,
    srcfeature_id integer,
    fmin integer,
    is_fmin_partial boolean DEFAULT false NOT NULL,
    fmax integer,
    is_fmax_partial boolean DEFAULT false NOT NULL,
    strand smallint,
    phase integer,
    residue_info text,
    locgroup integer DEFAULT 0 NOT NULL,
    rank integer DEFAULT 0 NOT NULL,
    CONSTRAINT featureloc_c2 CHECK ((fmin <= fmax))
);


ALTER TABLE public.private_featureloc OWNER TO postgres;

--
-- Primary Key
--

CREATE SEQUENCE private_featureloc_featureloc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.private_featureloc_featureloc_id_seq OWNER TO postgres;

ALTER SEQUENCE private_featureloc_featureloc_id_seq OWNED BY private_featureloc.featureloc_id;

ALTER TABLE ONLY private_featureloc ALTER COLUMN featureloc_id SET DEFAULT nextval('private_featureloc_featureloc_id_seq'::regclass);

ALTER TABLE ONLY private_featureloc
    ADD CONSTRAINT private_featureloc_pkey PRIMARY KEY (featureloc_id);


--
-- Constraints 
--

ALTER TABLE ONLY private_featureloc
    ADD CONSTRAINT private_featureloc_c1 UNIQUE (feature_id, locgroup, rank);


--
-- Indices
--

CREATE INDEX private_binloc_boxrange ON private_featureloc USING gist (boxrange(fmin, fmax));


CREATE INDEX private_binloc_boxrange_src ON private_featureloc USING gist (boxrange(srcfeature_id, fmin, fmax));


CREATE INDEX private_featureloc_idx1 ON private_featureloc USING btree (feature_id);


CREATE INDEX private_featureloc_idx2 ON private_featureloc USING btree (srcfeature_id);


CREATE INDEX private_featureloc_idx3 ON private_featureloc USING btree (srcfeature_id, fmin, fmax);


--
-- Foreign Keys
--

ALTER TABLE ONLY private_featureloc
    ADD CONSTRAINT private_featureloc_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


ALTER TABLE ONLY private_featureloc
    ADD CONSTRAINT private_featureloc_srcfeature_id_fkey FOREIGN KEY (srcfeature_id) REFERENCES private_feature(feature_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;



--
-- Name: private_feature_cvterm; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE private_feature_cvterm (
    feature_cvterm_id integer NOT NULL,
    feature_id integer NOT NULL,
    cvterm_id integer NOT NULL,
    pub_id integer NOT NULL,
    is_not boolean DEFAULT false NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.private_feature_cvterm OWNER TO postgres;


--
-- Primary Key
--

CREATE SEQUENCE private_feature_cvterm_feature_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.private_feature_cvterm_feature_cvterm_id_seq OWNER TO postgres;

ALTER SEQUENCE private_feature_cvterm_feature_cvterm_id_seq OWNED BY private_feature_cvterm.feature_cvterm_id;

ALTER TABLE ONLY private_feature_cvterm ALTER COLUMN feature_cvterm_id SET DEFAULT nextval('private_feature_cvterm_feature_cvterm_id_seq'::regclass);

ALTER TABLE ONLY private_feature_cvterm
    ADD CONSTRAINT private_feature_cvterm_pkey PRIMARY KEY (feature_cvterm_id);


--
-- Constraints
--

ALTER TABLE ONLY private_feature_cvterm
    ADD CONSTRAINT private_feature_cvterm_c1 UNIQUE (feature_id, cvterm_id, pub_id, rank);


--
-- Indices 
--

CREATE INDEX private_feature_cvterm_idx1 ON private_feature_cvterm USING btree (feature_id);


CREATE INDEX private_feature_cvterm_idx2 ON private_feature_cvterm USING btree (cvterm_id);


CREATE INDEX private_feature_cvterm_idx3 ON private_feature_cvterm USING btree (pub_id);


--
-- Foreign Keys
--

ALTER TABLE ONLY private_feature_cvterm
    ADD CONSTRAINT private_feature_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


ALTER TABLE ONLY private_feature_cvterm
    ADD CONSTRAINT private_feature_cvterm_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES private_feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


ALTER TABLE ONLY private_feature_cvterm
    ADD CONSTRAINT private_feature_cvterm_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;



COMMIT;
