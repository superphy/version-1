

--
-- SQL for linking cvterm ecoli_marker_regions to pangenome features
--   NOTE: This script uses IDs and cannot be transfered between database versions with different feature, cvterm or pub ID sets
--
--

CREATE OR REPLACE FUNCTION add_ecoli_markers()
  RETURNS boolean
AS $$
DECLARE
    marker_cvterm_id integer := 0;
    pub_id integer := 0;
    rank integer := 0;
    i integer := 0;
    features integer[] := array[3159571,3159808,3159389,3160196,3158082,3158667,3158844,3160113,3160296,3160548];
BEGIN

	EXECUTE
		'SELECT cvterm_id FROM cvterm WHERE name = ' || quote_literal('ecoli_marker_region')
		INTO marker_cvterm_id;

	IF marker_cvterm_id = 0 THEN
		RAISE EXCEPTION 'ecoli_marker_region cvterm_id not found';
	END IF;

	EXECUTE
		'SELECT pub_id FROM pub WHERE uniquename = ' || quote_literal('null')
		INTO pub_id;

	IF pub_id = 0 THEN
		RAISE EXCEPTION 'Default pub_id not found';
	END IF;

	FOREACH i IN ARRAY features
	LOOP 
		EXECUTE
			'INSERT INTO feature_cvterm (feature_id, cvterm_id, pub_id, is_not, rank) ' ||
			'SELECT ' || i || ', ' || marker_cvterm_id || ', ' || pub_id || ', FALSE, 0 ' ||
			'WHERE NOT EXISTS (	SELECT feature_cvterm_id FROM feature_cvterm WHERE feature_id = ' || i || ' AND ' ||
			'cvterm_id = ' || marker_cvterm_id || ')';
	END LOOP;

	RETURN TRUE;
END
$$
VOLATILE
LANGUAGE 'plpgsql';

BEGIN;

SELECT add_ecoli_markers();

COMMIT;