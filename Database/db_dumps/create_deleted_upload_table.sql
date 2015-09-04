BEGIN;

--
-- SQL for creating additional table for recording uploads that were deleted
--   by users.
--

SET search_path = public, pg_catalog;
SET default_tablespace = '';


-----------------------------------------------------------------------------
--
-- Table Name: deleted_upload; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE deleted_upload (
	deleted_upload_id         integer NOT NULL,
	upload_id                 integer NOT NULL,
	upload_date               TIMESTAMP NOT NULL,
	cc_feature_id	          integer NOT NULL,
	cc_uniquename             text NOT NULL,
	username                  varchar(20) NOT NULL,
	deletion_date             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE public.deleted_upload OWNER TO postgres;

--
-- primary key
--
CREATE SEQUENCE deleted_upload_deleted_upload_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.deleted_upload_deleted_upload_id_seq OWNER TO postgres;

ALTER SEQUENCE deleted_upload_deleted_upload_id_seq OWNED BY deleted_upload.deleted_upload_id;

ALTER TABLE ONLY deleted_upload ALTER COLUMN deleted_upload_id SET DEFAULT nextval('deleted_upload_deleted_upload_id_seq'::regclass);

ALTER TABLE ONLY deleted_upload
	ADD CONSTRAINT deleted_upload_pkey PRIMARY KEY (deleted_upload_id);

COMMIT;
