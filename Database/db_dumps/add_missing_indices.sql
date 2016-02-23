BEGIN;

--
-- SQL for adding missing indices.
--

SET search_path = public, pg_catalog;
SET default_tablespace = '';


-----------------------------------------------------------------------------
--
-- Drop unused tables 
--
DROP TABLE IF EXISTS raw_virulence_data ;
DROP TABLE IF EXISTS raw_amr_data;

-----------------------------------------------------------------------------
--
-- snp_variation table
--
CREATE INDEX snp_variation_idx3 ON snp_variation USING btree (contig_id);
CREATE INDEX snp_variation_idx4 ON snp_variation USING btree (locus_id);

----------------------------------------------------------------------------
--
-- snp_variation table
--
CREATE INDEX private_snp_variation_idx3 ON private_snp_variation USING btree (contig_id);
CREATE INDEX private_snp_variation_idx4 ON private_snp_variation USING btree (locus_id);

-----------------------------------------------------------------------------
--
-- snp_position table
--
CREATE INDEX snp_position_idx1 ON snp_position USING btree (contig_id);
CREATE INDEX snp_position_idx2 ON snp_position USING btree (pangenome_region_id);

-----------------------------------------------------------------------------
--
-- private_snp_position table
--
CREATE INDEX private_snp_position_idx1 ON private_snp_position USING btree (contig_id);
CREATE INDEX private_snp_position_idx2 ON private_snp_position USING btree (pangenome_region_id);

-----------------------------------------------------------------------------
--
-- private_gap_position table
--
CREATE INDEX private_gap_position_idx1 ON private_gap_position USING btree (contig_id);
CREATE INDEX private_gap_position_idx2 ON private_gap_position USING btree (pangenome_region_id);
CREATE INDEX private_gap_position_idx3 ON private_gap_position USING btree (contig_collection_id);
CREATE INDEX private_gap_position_idx4 ON private_gap_position USING btree (locus_id);

-----------------------------------------------------------------------------
--
-- gap_position table
--
CREATE INDEX gap_position_idx1 ON gap_position USING btree (contig_id);
CREATE INDEX gap_position_idx2 ON gap_position USING btree (pangenome_region_id);
CREATE INDEX gap_position_idx3 ON gap_position USING btree (contig_collection_id);
CREATE INDEX gap_position_idx4 ON gap_position USING btree (locus_id);

-----------------------------------------------------------------------------
--
-- genome_location table
--
CREATE INDEX genome_location_idx1 ON genome_location USING btree (feature_id);
CREATE INDEX genome_location_idx2 ON genome_location USING btree (geocode_id);

-----------------------------------------------------------------------------
--
-- private_genome_location table
--
CREATE INDEX private_genome_location_idx1 ON private_genome_location USING btree (feature_id);
CREATE INDEX private_genome_location_idx2 ON private_genome_location USING btree (geocode_id);

-----------------------------------------------------------------------------
--
-- vf_category table
--
CREATE INDEX vf_category_idx1 ON vf_category USING btree (feature_id);
CREATE INDEX vf_category_idx2 ON vf_category USING btree (gene_cvterm_id);

-----------------------------------------------------------------------------
--
-- vf_category table
--
CREATE INDEX amr_category_idx1 ON vf_category USING btree (feature_id);
CREATE INDEX amr_category_idx2 ON vf_category USING btree (gene_cvterm_id);

-----------------------------------------------------------------------------
--
-- contig_footprint table
--
CREATE INDEX contig_footprint_idx2 ON contig_footprint USING btree (feature_id);

-----------------------------------------------------------------------------
--
-- tracker table
--
CREATE INDEX tracker_idx2 ON tracker USING btree (upload_id);

-----------------------------------------------------------------------------
--
-- private_feature table
--
CREATE INDEX private_feature_idx6 ON private_feature USING btree (upload_id);

-----------------------------------------------------------------------------
--
-- private_featureprop table
--
CREATE INDEX private_featureprop_idx6 ON private_featureprop USING btree (upload_id);



COMMIT;
