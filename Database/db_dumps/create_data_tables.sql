BEGIN;

-- Table: raw_amr_data

-- DROP TABLE raw_amr_data;

CREATE TABLE raw_amr_data
(
  serial_id serial NOT NULL,
  genome_id character varying NOT NULL, -- ID of the genome that constains the current gene
  gene_id integer NOT NULL, -- Is  a foreign key to feature_id the feature tabe
  presence_absence integer NOT NULL DEFAULT 0,
  CONSTRAINT raw_amr_data_pkey PRIMARY KEY (serial_id),
  CONSTRAINT raw_amr_feature_id_fkey FOREIGN KEY (gene_id)
      REFERENCES feature (feature_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
)
WITH (
  OIDS=FALSE
);
ALTER TABLE raw_amr_data
  OWNER TO postgres;
COMMENT ON COLUMN raw_amr_data.genome_id IS 'ID of the genome that constains the current gene';
COMMENT ON COLUMN raw_amr_data.gene_id IS 'Is  a foreign key to feature_id the feature tabe';


-- Index: raw_amr_gene_id

-- DROP INDEX raw_amr_gene_id;

-- CREATE INDEX raw_amr_gene_id
--   ON raw_amr_data
--   USING btree
--   (gene_id);

-- Index: raw_amr_genome_id

-- DROP INDEX raw_amr_genome_id;

CREATE INDEX raw_amr_genome_id
  ON raw_amr_data
  USING btree
  (genome_id COLLATE pg_catalog."default");

COMMIT;

BEGIN;

-- Table: raw_virulence_data

-- DROP TABLE raw_virulence_data;

CREATE TABLE raw_virulence_data
(
  serial_id serial NOT NULL,
  genome_id character varying NOT NULL,
  gene_id integer NOT NULL,
  presence_absence integer NOT NULL DEFAULT 0,
  CONSTRAINT raw_virulence_data_pkey PRIMARY KEY (serial_id),
  CONSTRAINT raw_virulence_data_feature_id_fkey FOREIGN KEY (gene_id)
      REFERENCES feature (feature_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
)
WITH (
  OIDS=FALSE
);
ALTER TABLE raw_virulence_data
  OWNER TO postgres;

-- Index: raw_virulence_gene_id

-- DROP INDEX raw_virulence_gene_id;

-- CREATE INDEX raw_virulence_gene_id
--   ON raw_virulence_data
--   USING btree
--   (gene_id);

-- Index: raw_virulence_genome_id

-- DROP INDEX raw_virulence_genome_id;

CREATE INDEX raw_virulence_genome_id
  ON raw_virulence_data
  USING btree
  (genome_id COLLATE pg_catalog."default");

COMMIT;

-- BEGIN;

-- Table: loci

-- DROP TABLE loci;

-- CREATE TABLE loci
-- (
--   locus_id bigserial NOT NULL, -- Serial ID (integer) generated for each locus
--   locus_name character varying NOT NULL, -- Locus name (can contain both char and int)
--   locus_function character varying,
--   CONSTRAINT loci_pkey PRIMARY KEY (locus_id)
-- )
-- WITH (
--   OIDS=FALSE
-- );
-- ALTER TABLE loci
--   OWNER TO postgres;
-- COMMENT ON TABLE loci
--   IS 'Stores the names and, in the future, other info (accession, location, other properties) of loci used to compare groups of strains.';
-- COMMENT ON COLUMN loci.locus_id IS 'Serial ID (integer) generated for each locus';
-- COMMENT ON COLUMN loci.locus_name IS 'Locus name (can contain both char and int)';-- 

-- COMMIT;

BEGIN;

-- Table: loci_genotypes

-- DROP TABLE loci_genotypes;

CREATE TABLE loci_genotypes
(
  locus_genotype_id serial NOT NULL,
  genome_id character varying NOT NULL, -- Strain ID
  feature_id integer NOT NULL, -- Stores a locus ID from the loci table
  locus_genotype integer NOT NULL DEFAULT 0, -- Presence absence value for each locus for each strain. Will have a value either 0 or 1. Default is 0.
  CONSTRAINT loci_genotypes_pkey PRIMARY KEY (locus_genotype_id),
  CONSTRAINT feature_id_fkey FOREIGN KEY (feature_id)
      REFERENCES feature (feature_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
)
WITH (
  OIDS=FALSE
);
ALTER TABLE loci_genotypes
  OWNER TO postgres;
COMMENT ON TABLE loci_genotypes
  IS 'Presence absence values for each locus for each strain ';
COMMENT ON COLUMN loci_genotypes.locus_genotype IS 'Presence absence value for each locus for each strain. Will have a value either 0 or 1. Default is 0.';

-- Index: loci_genotypes_idx1

-- DROP INDEX loci_genotypes_idx1;

CREATE INDEX loci_genotypes_idx1
  ON loci_genotypes
  USING btree
  (feature_id);

-- Index: loci_genotypes_idx2

-- DROP INDEX loci_genotypes_idx2;

CREATE INDEX loci_genotypes_idx2
  ON loci_genotypes
  USING btree
  (genome_id);

COMMIT;

BEGIN;

-- Table: snps_genotypes

-- DROP TABLE snps_genotypes;

CREATE TABLE snps_genotypes
(
  snp_genotype_id serial NOT NULL,
  genome_id character varying NOT NULL, -- Strain ID
  feature_id integer NOT NULL, -- Stores a snp ID from the snps table
  snp_a integer NOT NULL DEFAULT 0, -- Presence absence value for base "A" for each locus for each strain. Default is 0.
  snp_t integer NOT NULL DEFAULT 0, -- Presence absence value for base "T" for each locus for each strain. Default is 0.
  snp_c integer NOT NULL DEFAULT 0, -- Presence absence value for base "C" for each locus for each strain. Default is 0.
  snp_g integer NOT NULL DEFAULT 0, -- Presence absence value for base "G" for each locus for each strain. Default is 0.
  CONSTRAINT snp_genotypes_pkey PRIMARY KEY (snp_genotype_id),
  CONSTRAINT feature_id_fkey FOREIGN KEY (feature_id)
      REFERENCES feature (feature_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
)
WITH (
  OIDS=FALSE
);
ALTER TABLE snps_genotypes
  OWNER TO postgres;
COMMENT ON TABLE snps_genotypes
  IS 'Presence absence values for each snp for each strain';
COMMENT ON COLUMN snps_genotypes.snp_a IS 'Presence absence value for base "A" for each locus for each strain. Default is 0.';
COMMENT ON COLUMN snps_genotypes.snp_t IS 'Presence absence value for base "T" for each locus for each strain. Default is 0.';
COMMENT ON COLUMN snps_genotypes.snp_c IS 'Presence absence value for base "C" for each locus for each strain. Default is 0.';
COMMENT ON COLUMN snps_genotypes.snp_g IS 'Presence absence value for base "G" for each locus for each strain. Default is 0.';

-- Index: snps_genotypes_idx1

-- DROP INDEX snps_genotypes_idx1;

CREATE INDEX snps_genotypes_idx1
  ON snps_genotypes
  USING btree
  (feature_id);


-- Index: snps_genotypes_idx2

-- DROP INDEX snps_genotypes_idx2;

CREATE INDEX snps_genotypes_idx2
  ON snps_genotypes
  USING btree
  (genome_id);

COMMIT;

BEGIN;

-- Table: amr_category

-- DROP TABLE amr_category;

CREATE TABLE amr_category
(
  amr_category_id serial NOT NULL,
  parent_category_id integer NOT NULL,
  category_id integer NOT NULL, -- Cvterm_id for category....
  gene_cvterm_id integer NOT NULL, -- Cvterm_id for amr gene. ...
  feature_id integer, -- Stores the feature_id for each AMR gene. Is a foreign key to the feature table. Maps to cvterm_id from the feature_cvterm table.
  CONSTRAINT amr_category_pkey PRIMARY KEY (amr_category_id),
  CONSTRAINT amr_category_cvterm_fkey FOREIGN KEY (category_id)
      REFERENCES cvterm (cvterm_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT amr_gene_cvterm_fkey FOREIGN KEY (gene_cvterm_id)
      REFERENCES cvterm (cvterm_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT feature_id_feature_fkey FOREIGN KEY (feature_id)
      REFERENCES feature (feature_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT parent_category_cvterm_fkey FOREIGN KEY (parent_category_id)
      REFERENCES cvterm (cvterm_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
)
WITH (
  OIDS=FALSE
);
ALTER TABLE amr_category
  OWNER TO postgres;
COMMENT ON TABLE amr_category
  IS 'Table that maps AMR category type_ids to gene feature_ids';
COMMENT ON COLUMN amr_category.gene_cvterm_id IS 'Cvterm_id for amr gene. 
Is a foregn key to the Cvterm table.';
COMMENT ON COLUMN amr_category.category_id IS 'Cvterm_id for category.
Is a foreign key to the Cvterm table.';
COMMENT ON COLUMN amr_category.feature_id IS 'Stores the feature_id for each AMR gene. Is a foreign key to the feature table. Maps to cvterm_id from the feature_cvterm table.';


COMMIT;

BEGIN;

-- Table: vf_category

-- DROP TABLE vf_category;

CREATE TABLE vf_category
(
  vf_category_id serial NOT NULL,
  parent_category_id integer NOT NULL,
  category_id integer NOT NULL, -- Cvterm_id for category....
  gene_cvterm_id integer NOT NULL, -- Cvterm_id for vf gene. ...
  feature_id integer, -- Stores the feature_id for each VF gene. Is a foreign key to the feature table. Maps to cvterm_id from the feature_cvterm table.
  CONSTRAINT vf_category_pkey PRIMARY KEY (vf_category_id),
  CONSTRAINT vf_category_cvterm_fkey FOREIGN KEY (category_id)
      REFERENCES cvterm (cvterm_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT vf_gene_cvterm_fkey FOREIGN KEY (gene_cvterm_id)
      REFERENCES cvterm (cvterm_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT feature_id_feature_fkey FOREIGN KEY (feature_id)
      REFERENCES feature (feature_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT parent_category_cvterm_fkey FOREIGN KEY (parent_category_id)
      REFERENCES cvterm (cvterm_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
)
WITH (
  OIDS=FALSE
);
ALTER TABLE vf_category
  OWNER TO postgres;
COMMENT ON TABLE vf_category
  IS 'Table that maps VF category type_ids to gene feature_ids';
COMMENT ON COLUMN vf_category.category_id IS 'Cvterm_id for category.
Is a foreign key to the Cvterm table.';
COMMENT ON COLUMN vf_category.gene_cvterm_id IS 'Cvterm_id for vf gene. 
Is a foregn key to the Cvterm table.';
COMMENT ON COLUMN vf_category.feature_id IS 'Stores the feature_id for each VF gene. Is a foreign key to the feature table. Maps to cvterm_id from the feature_cvterm table.';

COMMIT;

BEGIN;

-- Table: job_result

-- DROP TABLE job_result;

CREATE TABLE job_result
(
  job_result_id character varying(255) NOT NULL,
  remote_address inet,
  session_id character varying(255),
  user_id integer,
  username character varying(255),
  user_config json NOT NULL,
  job_result_status character varying(255) NOT NULL,
  result json,
  CONSTRAINT job_results_pkey PRIMARY KEY (job_result_id),
  CONSTRAINT user_id_fkey FOREIGN KEY (user_id)
      REFERENCES login (login_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
)
WITH (
  OIDS=FALSE
);
ALTER TABLE job_result
  OWNER TO genodo;
COMMENT ON TABLE job_result
  IS 'Table for long-polling group wise comparisons. Stores job requests, user configurations and results (if generated)';

COMMIT;


