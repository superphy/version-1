BEGIN;

--
-- SQL for creating additional table for recording pending delete and update jobs
--

SET search_path = public, pg_catalog;
SET default_tablespace = '';


-----------------------------------------------------------------------------
--
-- Table Name: pending_update; Schema: public;  Tablespace: 
--

CREATE TABLE pending_update (
	pending_update_id       integer NOT NULL,
	step                    integer NOT NULL DEFAULT 0,
	failed                  boolean NOT NULL DEFAULT FALSE,
	job_method              varchar(255),
	job_input               text,
	upload_id               integer,
	login_id                integer NOT NULL DEFAULT 0,
	start_date              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	end_date                TIMESTAMP
);

--
-- primary key
--
CREATE SEQUENCE pending_update_pending_update_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER SEQUENCE pending_update_pending_update_id_seq OWNED BY pending_update.pending_update_id;

ALTER TABLE ONLY pending_update ALTER COLUMN pending_update_id SET DEFAULT nextval('pending_update_pending_update_id_seq'::regclass);

ALTER TABLE ONLY pending_update
	ADD CONSTRAINT pending_update_pkey PRIMARY KEY (pending_update_id);

--
-- foreign keys
--
ALTER TABLE ONLY pending_update
	ADD CONSTRAINT pending_update_login_id_fkey FOREIGN KEY (login_id) REFERENCES login(login_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY pending_update
	ADD CONSTRAINT pending_update_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES upload(upload_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Constraints
--
CREATE INDEX pending_update_idx1 ON pending_update USING btree (upload_id,login_id);
CREATE INDEX pending_update_idx2 ON pending_update USING btree (upload_id,login_id,step,failed);


COMMIT;
