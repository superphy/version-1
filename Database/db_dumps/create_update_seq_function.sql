BEGIN;

--
-- SQL for creating util function for updating primary key sequences after loading
--

SET search_path = public, pg_catalog;
SET default_tablespace = '';


--
-- Utility function - updates primary key sequence to max value
--
-- USAGE: SELECT update_seq('tablename');
--

CREATE OR REPLACE FUNCTION update_seq(tname text)
  RETURNS integer
AS $$
DECLARE
    maxk integer := 0;
    nseq integer := 0;
    pkey text;
    pseq text;
BEGIN

    --primary key
    pkey := tname || '_id';

    --seq name
    pseq := tname || '_' || tname || '_id_seq';

    --find max value
    EXECUTE 'SELECT MAX(' || pkey || ') FROM ' || tname INTO maxk;

    IF maxk = 0 THEN 
        RAISE EXCEPTION 'Invalid primary key value';
    END IF;

    --find seq value
    EXECUTE 'SELECT nextval(''' || pseq || ''')' INTO nseq;

    --update seq value if needed
    IF maxk > nseq THEN
        RAISE INFO 'Updating primary key';
        EXECUTE 'SELECT setval(''' || pseq || ''', ' || maxk || ')';
    ELSE
	RAISE INFO 'Primary key ok';
    END IF;


    RETURN maxk;
    
END
$$
IMMUTABLE
LANGUAGE 'plpgsql';


COMMIT;
