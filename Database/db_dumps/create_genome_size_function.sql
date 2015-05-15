--
-- Utility function - returns genome size by adding string length of all contigs belonging to contig_collection
--
-- USAGE: SELECT feature.genome_size FROM feature WHERE type_id = ;
--

CREATE OR REPLACE FUNCTION genome_size(cc feature)
  RETURNS integer
AS $$
DECLARE
    size integer := 0;
    cc_type integer;
    c_type integer;
    r_type integer;
    dnalen integer := 0;
BEGIN

	SELECT cvterm_id INTO cc_type FROM cvterm WHERE name = 'contig_collection';
	SELECT cvterm_id INTO c_type FROM cvterm WHERE name = 'contig';
	SELECT cvterm_id INTO r_type FROM cvterm c, cv v WHERE c.name = 'part_of' AND v.name = 'relationship' AND c.cv_id = v.cv_id;

	IF cc.type_id != cc_type THEN
	    RAISE EXCEPTION 'Cannot call genome size on feature that is not a contig collection.'; 
	END IF;

	FOR dnalen IN SELECT f.seqlen FROM feature f, feature_relationship r 
    	WHERE r.object_id = cc.feature_id AND r.type_id = r_type AND f.feature_id = r.subject_id AND f.type_id = c_type
    LOOP
    	size = size + dnalen;
    END LOOP;
   
	RETURN size;
    
END
$$
IMMUTABLE
LANGUAGE 'plpgsql';