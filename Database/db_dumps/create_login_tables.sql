--
-- SQL for creating additional tables for login sessions and sequence uploads
--

SET search_path = public, pg_catalog;
SET default_tablespace = '';

--
-- Table Name: sessions; Schema: public; Owner: postgres; Tablespace: 
--
CREATE TABLE sessions (
	id CHAR(32) NOT NULL PRIMARY KEY,
	a_session BYTEA NOT NULL
);
ALTER TABLE public.sessions OWNER TO postgres;

--
-- Table Name: login; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE login (
	login_id       integer NOT NULL,
	username       varchar(20) NOT NULL,
	password       varchar(22) NOT NULL,
	firstname      varchar(30) NOT NULL DEFAULT '',
	lastname       varchar(30) NOT NULL DEFAULT '',
	email          varchar(45) NOT NULL,
	creation_date  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE public.login OWNER TO postgres;

--
-- primary key
--
CREATE SEQUENCE login_login_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.login_login_id_seq OWNER TO postgres;

ALTER SEQUENCE login_login_id_seq OWNED BY login.login_id;

ALTER TABLE ONLY login ALTER COLUMN login_id SET DEFAULT nextval('login_login_id_seq'::regclass);

ALTER TABLE ONLY login
	ADD CONSTRAINT login_pkey PRIMARY KEY (login_id);

--
-- Constraints
--
ALTER TABLE ONLY login
	ADD CONSTRAINT login_c1 UNIQUE (username);

COMMENT ON INDEX login_c1 IS 'Each user must have a unique username.';

--
-- Indices 
--







