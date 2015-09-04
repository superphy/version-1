--
-- Pl/Pgsql function for more efficient bulk deletes on feature table
--

CREATE OR REPLACE FUNCTION featurebulkdelete(cvtype integer, dochecks boolean)
  RETURNS VOID AS
$$
DECLARE

  num INTEGER;
  i INTEGER := 1;
  n INTEGER;
  chunk INTEGER := 1000;
  tablenames VARCHAR[] := ARRAY[
    'feature_relationship',
    'feature_relationship',
    'feature_cvterm',
    'feature_dbxref',
    'amr_category',
    'vf_category',
    'feature_tree',
    'featureloc',
    'featureloc',
    'featureprop',
    'gap_position',
    'gap_position',
    'gap_position',
    'gap_position',
    'pripub_feature_relationship',
    'private_gap_position',
    'private_snp_position',
    'pubpri_feature_relationship',
    'snp_core',
    'snp_position',
    'snp_position',
    'snp_position',
    'snp_position',
    'snp_variation',
    'snp_variation',
    'snp_variation'
  ];
  colnames VARCHAR[]  := ARRAY[
    'subject_id',
    'object_id',
    'feature_id',
    'feature_id',
    'feature_id',
    'feature_id',
    'feature_id',
    'feature_id',
    'srcfeature_id',
    'feature_id',
    'contig_collection_id',
    'contig_id',
    'locus_id',
    'pangenome_region_id',
    'object_id',
    'pangenome_region_id',
    'pangenome_region_id',
    'subject_id',
    'pangenome_region_id',
    'contig_collection_id',
    'contig_id',
    'locus_id',
    'pangenome_region_id',
    'contig_collection_id',
    'contig_id',
    'locus_id'
  ];
  tablename VARCHAR;
  colname VARCHAR;

BEGIN

  -- Find feature_ids that need to be deleted and insert into temp table
  EXECUTE format('CREATE TABLE my_delete_list AS SELECT feature_id FROM feature WHERE type_id = %L', cvtype);
  ALTER TABLE ONLY my_delete_list
    ADD CONSTRAINT my_delete_list_c1 UNIQUE (feature_id);

  -- Find number of rows
  num := COUNT(*) FROM my_delete_list;
  RAISE NOTICE 'Number of rows to delete: %', num;


  IF dochecks THEN
  -- Make sure deleted IDs are not foreign keys in other tables

    RAISE NOTICE 'Checking referential integrity...';

    FOREACH tablename IN ARRAY tablenames LOOP
      colname := colnames[i];
      i := i + 1;
      RAISE NOTICE '  checking %.%', tablename, colname;

      EXECUTE format('SELECT 1 FROM %I r, my_delete_list d WHERE r.%I = d.feature_id', tablename, colname);
      GET DIAGNOSTICS n = ROW_COUNT;

      IF n > 0 THEN
        RAISE EXCEPTION 'Failed reference checks. Delete row(s) found in %.%', tablename, colname;
      END IF;
      
    END LOOP;
  
  END IF;

  -- Turn off constraints
  RAISE NOTICE 'Deleting feature rows...';
  ALTER TABLE feature DISABLE TRIGGER ALL;

  -- Perform delete operations chunks at a time
  FOR i IN 0 .. num BY chunk LOOP
  
    RAISE NOTICE '  deleting row block %', i;
    DELETE FROM feature WHERE feature_id IN (
      SELECT feature_id FROM my_delete_list LIMIT chunk OFFSET i
    );
   
  END LOOP;
  

  -- Drop temp table
  DROP TABLE my_delete_list;

  -- Turn on constraints
  ALTER TABLE feature ENABLE TRIGGER ALL;
  RAISE NOTICE 'Complete.';


END;
$$
LANGUAGE 'plpgsql' VOLATILE
SECURITY DEFINER;






