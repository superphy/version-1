BEGIN;

--
-- SQL for creating additional table for tracking progress of analysis of user's
--   uploaded genome
--

SET search_path = public, pg_catalog;
SET default_tablespace = '';


-----------------------------------------------------------------------------
--
-- Table Name: tracker; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE tracker (
	tracker_id       integer NOT NULL,
	step             integer NOT NULL DEFAULT 0,
	failed           boolean NOT NULL DEFAULT FALSE,
	feature_name     varchar(255),
	access_category  varchar(10),
	command          varchar(255),
	pid              varchar(100),
	upload_id        integer,
	login_id         integer NOT NULL DEFAULT 0,
	start_date       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	end_date         TIMESTAMP,
	footprint        varchar(32)
);

ALTER TABLE public.tracker OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE tracker_tracker_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.tracker_tracker_id_seq OWNER TO genodo;

ALTER SEQUENCE tracker_tracker_id_seq OWNED BY tracker.tracker_id;

ALTER TABLE ONLY tracker ALTER COLUMN tracker_id SET DEFAULT nextval('tracker_tracker_id_seq'::regclass);

ALTER TABLE ONLY tracker
	ADD CONSTRAINT tracker_pkey PRIMARY KEY (tracker_id);

--
-- foreign keys
--
ALTER TABLE ONLY tracker
	ADD CONSTRAINT tracker_login_id_fkey FOREIGN KEY (login_id) REFERENCES login(login_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY tracker
	ADD CONSTRAINT tracker_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES upload(upload_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Indices 
--
CREATE INDEX tracker_idx1 ON tracker USING btree (footprint);

COMMIT;
