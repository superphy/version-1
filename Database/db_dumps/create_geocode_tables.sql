BEGIN;

-- Table: geocoded_location

-- DROP TABLE geocoded_location;

CREATE TABLE geocoded_location
(
  geocode_id serial NOT NULL,
  location json NOT NULL,
  search_query character varying(255) DEFAULT NULL::character varying, -- Can be NULL if a pin-pointed location
  CONSTRAINT geocoded_location_pkey PRIMARY KEY (geocode_id)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE geocoded_location
  OWNER TO genodo;
COMMENT ON TABLE geocoded_location
  IS 'Stores latlng coordinates of genome locations in JSON objects.';
COMMENT ON COLUMN geocoded_location.search_query IS 'Can be NULL if a pin-pointed location';

COMMIT;

BEGIN;

-- Table: genome_location

-- DROP TABLE genome_location;

CREATE TABLE genome_location
(
  geocode_id integer NOT NULL,
  feature_id integer NOT NULL,
  CONSTRAINT genome_location_pkey PRIMARY KEY (geocode_id, feature_id),
  CONSTRAINT genome_location_feature_fkey FOREIGN KEY (feature_id)
      REFERENCES feature (feature_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT genome_location_geocode_fkey FOREIGN KEY (geocode_id)
      REFERENCES geocoded_location (geocode_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
)
WITH (
  OIDS=FALSE
);
ALTER TABLE genome_location
  OWNER TO genodo;

COMMIT;

BEGIN;

-- Table: private_genome_location

-- DROP TABLE private_genome_location;

CREATE TABLE private_genome_location
(
  geocode_id integer NOT NULL,
  feature_id integer NOT NULL,
  CONSTRAINT private_genome_location_pkey PRIMARY KEY (geocode_id, feature_id),
  CONSTRAINT private_genome_location_feature_fkey FOREIGN KEY (feature_id)
      REFERENCES private_feature (feature_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT private_genome_location_geocode_fkey FOREIGN KEY (geocode_id)
      REFERENCES geocoded_location (geocode_id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
)
WITH (
  OIDS=FALSE
);
ALTER TABLE private_genome_location
  OWNER TO genodo;
  
COMMIT;