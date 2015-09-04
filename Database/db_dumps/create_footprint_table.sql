BEGIN;

--
-- SQL for creating additional table for storing genome checksums
--

SET search_path = public, pg_catalog;
SET default_tablespace = '';


-----------------------------------------------------------------------------
--
-- Table Name: contig_footprint; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE contig_footprint (
	contig_footprint_id    integer NOT NULL,
	feature_id             integer NOT NULL,
	footprint              varchar(32)
);

ALTER TABLE public.contig_footprint OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE contig_footprint_contig_footprint_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.contig_footprint_contig_footprint_id_seq OWNER TO genodo;

ALTER SEQUENCE contig_footprint_contig_footprint_id_seq OWNED BY contig_footprint.contig_footprint_id;

ALTER TABLE ONLY contig_footprint ALTER COLUMN contig_footprint_id SET DEFAULT nextval('contig_footprint_contig_footprint_id_seq'::regclass);

ALTER TABLE ONLY contig_footprint
	ADD CONSTRAINT contig_footprint_pkey PRIMARY KEY (contig_footprint_id);

--
-- foreign keys
--
ALTER TABLE ONLY contig_footprint
	ADD CONSTRAINT contig_footprint_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

--
-- Indices 
--
CREATE INDEX contig_footprint_idx1 ON contig_footprint USING btree (footprint);

/*
--
-- Obsolete functions
--

CREATE OR REPLACE FUNCTION build_footprint(
	feature_id INTEGER, 
	ispublic BOOLEAN
) RETURNS VOID AS
$$
DECLARE
	feature_table VARCHAR(20);
	rel_table     VARCHAR(20);
	footp_table   VARCHAR(20);
	contig_id     INTEGER;
	collection_id INTEGER;
	partof_id     INTEGER;
	c             INTEGER;
	seqlen        INTEGER;
	contig        RECORD;
	sizes         INTEGER[] := '{}';
BEGIN

	-- Retrieve type IDs
	SELECT cvterm_id INTO contig_id FROM cvterm WHERE name = 'contig';
	SELECT cvterm_id INTO collection_id FROM cvterm WHERE name = 'contig_collection';
	SELECT cvterm_id INTO partof_id FROM cvterm t, cv v WHERE t.name = 'part_of' AND  v.name = 'relationship' AND t.cv_id = v.cv_id;

	-- Set table names
	IF ispublic THEN
		feature_table := 'feature';
		rel_table := 'feature_relationship';
		footp_table := 'contig_footprint';
	ELSE
		feature_table := 'private_feature';
		rel_table := 'private_feature_relationship';
		footp_table := 'private_contig_footprint';
	END IF;

	-- Verify contig_collection feature ID
	EXECUTE 'SELECT count(*) FROM ' ||
		quote_ident(feature_table) || 
		' WHERE type_id = $1 AND feature_id = $2'
	INTO c
	USING collection_id, feature_id;

	IF c != 1 THEN
    	RAISE EXCEPTION 'feature % not contig_collection type', feature_id;
	END IF;

	-- Insert empty record
	EXECUTE 'SELECT count(*) FROM ' || quote_ident(footp_table) || ' WHERE feature_id = $1'
	INTO c
	USING feature_id;
	IF c = 0 THEN
		EXECUTE 'INSERT INTO ' || quote_ident(footp_table) || ' (feature_id) VALUES ($1)'
		USING feature_id; 
	END IF;

	-- Build sizes array
	c := 0;
	FOR contig IN
		EXECUTE 'SELECT * FROM ' || quote_ident(rel_table) || ' r, ' ||
			quote_ident(feature_table) || ' f ' ||
			'WHERE r.type_id = $1 AND r.object_id = $2 AND r.subject_id = f.feature_id AND f.type_id = $3' 
			USING partof_id, feature_id, contig_id
	LOOP
		EXECUTE 'SELECT seqlen FROM ' ||
			quote_ident(feature_table) || 
			' WHERE type_id = $1 AND feature_id = $2'
		INTO seqlen
		USING contig_id, contig.subject_id;

		sizes := sizes || seqlen;
		c := c + 1;

	END LOOP;

	-- Sort array
	EXECUTE 'SELECT sort($1)'
	INTO sizes
	USING sizes;


	EXECUTE 'UPDATE ' || quote_ident(footp_table) ||
		' SET contig_num = $1, contig_sizes = $2'
		' WHERE feature_id = $3'
	USING c, sizes, feature_id;

   
END
$$
LANGUAGE 'plpgsql';

--
-- Compare footprint function
--
CREATE OR REPLACE FUNCTION compare_footprint(
	cnum     INTEGER, 
	csizes   INTEGER[],
	fptable  VARCHAR(10)
) RETURNS SETOF INTEGER AS
$$
DECLARE
	footp_table   VARCHAR(20);
	idname        VARCHAR(20);
BEGIN
	IF fptable = 'public' THEN
		-- Search public
		footp_table := 'contig_footprint';
		idname := 'feature_id';
	ELSE IF fptable = 'private' THEN
		-- Search private
		footp_table := 'private_contig_footprint';
		idname := 'feature_id';
	ELSE IF fptable = 'pending'
		-- Search pending table
		footp_table := 'tracker';
		idname := 'tracker_id';
	ELSE
		RAISE EXCEPTION 'Invalid parameter: fptable %. Allowable values: public|private|pending.', fptable;
	END IF;

	RETURN QUERY EXECUTE 'SELECT ' || quote_ident(idname) || ' FROM ' || quote_ident(footp_table) ||
		' WHERE contig_num = $1 AND contig_sizes = $2'
	USING cnum, csizes;

END
$$
LANGUAGE 'plpgsql';

--
-- Find identical contig function
--
CREATE OR REPLACE FUNCTION identical_contig(
	contig_seq     TEXT
	feature_id     INTEGER, 
	ispublic       BOOLEAN
) RETURNS BOOLEAN AS
$$
DECLARE
	feature_table VARCHAR(20);
	rel_table     VARCHAR(20);
	contig_id     INTEGER;
	collection_id INTEGER;
	partof_id     INTEGER;
	seq           TEXT;
BEGIN

	-- Retrieve type IDs
	SELECT cvterm_id INTO contig_id FROM cvterm WHERE name = 'contig';
	SELECT cvterm_id INTO collection_id FROM cvterm WHERE name = 'contig_collection';
	SELECT cvterm_id INTO partof_id FROM cvterm t, cv v WHERE t.name = 'part_of' AND  v.name = 'relationship' AND t.cv_id = v.cv_id;

	-- Set table names
	IF ispublic THEN
		feature_table := 'feature';
		rel_table := 'feature_relationship';
	ELSE
		feature_table := 'private_feature';
		rel_table := 'private_feature_relationship';
	END IF;

	-- Verify contig_collection feature ID
	EXECUTE 'SELECT count(*) FROM ' ||
		quote_ident(feature_table) || 
		' WHERE type_id = $1 AND feature_id = $2'
	INTO c
	USING collection_id, feature_id;

	IF c != 1 THEN
    	RAISE EXCEPTION 'feature % not contig_collection type', feature_id;
	END IF;

	-- Iterate through contigs of same size checking for identical contig sequences
	FOR seq IN
		EXECUTE 'SELECT f.residues FROM ' || quote_ident(rel_table) || ' r, ' ||
			quote_ident(feature_table) || ' f ' ||
			'WHERE r.type_id = $1 AND r.object_id = $2 AND r.subject_id = f.feature_id AND f.type_id = $3 AND f.seqlen = $4' 
			USING partof_id, feature_id, contig_id, char_length(contig_seq)
	LOOP

		IF seq = contig_seq THEN
			RETURN TRUE;
		END IF;

	END LOOP;

	RETURN FALSE;

END
$$
LANGUAGE 'plpgsql';

*/

COMMIT;


