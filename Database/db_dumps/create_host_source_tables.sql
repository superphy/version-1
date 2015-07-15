
BEGIN;

--
-- SQL for creating additional tables for hosts and associated sources
--

SET search_path = public, pg_catalog;
SET default_tablespace = '';

-----------------------------------------------------------------------------
--
-- Table Name: host_cateogry; Schema: public; Owner: genodo; ablespace: 
--

CREATE TABLE host_category (
	host_category_id integer NOT NULL,
	uniquename       varchar(20) NOT NULL,
	displayname      varchar(100) NOT NULL
);

ALTER TABLE public.host_category OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE host_category_host_category_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.host_category_host_category_id_seq OWNER TO genodo;

ALTER SEQUENCE host_category_host_category_id_seq OWNED BY host_category.host_category_id;

ALTER TABLE ONLY host_category ALTER COLUMN host_category_id SET DEFAULT nextval('host_category_host_category_id_seq'::regclass);

ALTER TABLE ONLY host_category
	ADD CONSTRAINT host_category_pkey PRIMARY KEY (host_category_id);

--
-- foreign keys
--

--
-- Constraints
--  
ALTER TABLE ONLY host_category
	ADD CONSTRAINT host_category_c1 UNIQUE (uniquename);

ALTER TABLE ONLY host_category
	ADD CONSTRAINT host_category_c2 UNIQUE (displayname);

--
-- Indices 
--


-----------------------------------------------------------------------------
--
-- Table Name: host; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE host (
	host_id          integer NOT NULL,
	host_category_id integer NOT NULL,
	uniquename       varchar(20) NOT NULL,
	displayname      varchar(100) NOT NULL,   
        commonname       varchar(100) NOT NULL,
        scientificname   varchar(100) NOT NULL
);

ALTER TABLE public.host OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE host_host_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.host_host_id_seq OWNER TO genodo;

ALTER SEQUENCE host_host_id_seq OWNED BY host.host_id;

ALTER TABLE ONLY host ALTER COLUMN host_id SET DEFAULT nextval('host_host_id_seq'::regclass);

ALTER TABLE ONLY host
	ADD CONSTRAINT host_pkey PRIMARY KEY (host_id);

--
-- foreign keys
--
ALTER TABLE ONLY host
	ADD CONSTRAINT host_host_category_id_fkey FOREIGN KEY (host_category_id) REFERENCES host_category(host_category_id);

--
-- Constraints
--  
ALTER TABLE ONLY host
	ADD CONSTRAINT host_c1 UNIQUE (uniquename);

ALTER TABLE ONLY host
	ADD CONSTRAINT host_c2 UNIQUE (displayname);

--
-- Indices 
--

-----------------------------------------------------------------------------
--
-- Table Name: source; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE source (
	source_id          integer NOT NULL,
	host_category_id integer NOT NULL,
	uniquename       varchar(20) NOT NULL,
	displayname      varchar(100) NOT NULL,
        description      text
);

ALTER TABLE public.source OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE source_source_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.source_source_id_seq OWNER TO genodo;

ALTER SEQUENCE source_source_id_seq OWNED BY source.source_id;

ALTER TABLE ONLY source ALTER COLUMN source_id SET DEFAULT nextval('source_source_id_seq'::regclass);

ALTER TABLE ONLY source
	ADD CONSTRAINT source_pkey PRIMARY KEY (source_id);

--
-- foreign keys
--
ALTER TABLE ONLY source
	ADD CONSTRAINT source_host_category_id_fkey FOREIGN KEY (host_category_id) REFERENCES host_category(host_category_id);

--
-- Constraints
--  
ALTER TABLE ONLY source
	ADD CONSTRAINT source_c1 UNIQUE (host_category_id, uniquename);

ALTER TABLE ONLY source
	ADD CONSTRAINT source_c2 UNIQUE (host_category_id, displayname);

--
-- Indices 
--

-----------------------------------------------------------------------------
--
-- Table Name: syndrome; Schema: public; Owner: genodo; Tablespace: 
--

CREATE TABLE syndrome (
	syndrome_id          integer NOT NULL,
	host_category_id integer NOT NULL,
	uniquename       varchar(20) NOT NULL,
	displayname      varchar(100) NOT NULL,
	description      text
);

ALTER TABLE public.syndrome OWNER TO genodo;

--
-- primary key
--
CREATE SEQUENCE syndrome_syndrome_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MINVALUE
	NO MAXVALUE
	CACHE 1;

ALTER TABLE public.syndrome_syndrome_id_seq OWNER TO genodo;

ALTER SEQUENCE syndrome_syndrome_id_seq OWNED BY syndrome.syndrome_id;

ALTER TABLE ONLY syndrome ALTER COLUMN syndrome_id SET DEFAULT nextval('syndrome_syndrome_id_seq'::regclass);

ALTER TABLE ONLY syndrome
	ADD CONSTRAINT syndrome_pkey PRIMARY KEY (syndrome_id);

--
-- foreign keys
--
ALTER TABLE ONLY syndrome
	ADD CONSTRAINT syndrome_host_category_id_fkey FOREIGN KEY (host_category_id) REFERENCES host_category(host_category_id);

--
-- Constraints
--  
ALTER TABLE ONLY syndrome
	ADD CONSTRAINT syndrome_c1 UNIQUE (host_category_id, uniquename);

ALTER TABLE ONLY syndrome
	ADD CONSTRAINT syndrome_c2 UNIQUE (host_category_id, displayname);

--
-- Indices 
--


COMMIT;

BEGIN;

-----------------------------------------------------------------------------
--
-- Populate tables
--

--
-- Data for Name: host_category; Type: TABLE DATA; Schema: public; Owner: genodo
--

COPY host_category (host_category_id, uniquename, displayname) FROM stdin;
1	human	Human
2	mammal	Non-human Mammalia
3	bird	Aves
4	env	Environmental Sources
\.


--
-- Data for Name: host; Type: TABLE DATA; Schema: public; Owner: genodo
--

COPY host (host_id, host_category_id, uniquename, displayname, commonname, scientificname) FROM stdin;
1	1	hsapiens	Homo sapiens (human)	human	Homo sapiens
2	2	btaurus	Bos taurus (cow)	cow	Bos taurus
3	2	sscrofa	Sus scrofa (pig)	pig	Sus scrofa
4	2	mmusculus	Mus musculus (mouse)	mouse	Mus musculus
5	2	oaries	Ovis aries (sheep)	sheep	Ovis aries
6	3	ggallus	Gallus gallus (chicken)	chicken	Gallus gallus
7	2	ocuniculus	Oryctolagus cuniculus (rabbit)	rabbit	Oryctolagus cuniculus
8	2	clupus	Canis lupus familiaris (dog)	dog	Canis lupus familiaris
9	2	fcatus	Felis catus (cat)	cat	Felis catus
10	4	environment	Environmental source	environment	Environmental source
11	2	other	Other (fill in adjacent fields)	other	User-specified Host
13	2	eferus	Equus ferus caballus (horse)	horse	Equus ferus caballus
14	2	caegagrus	Capra aegagrus hircus (goat)	goat	Capra aegagrus hircus
15	4	acepa	Allium cepa (onion)	onion	Allium cepa
\.


--
-- Name: host_category_host_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: genodo
--

SELECT pg_catalog.setval('host_category_host_category_id_seq', 5, true);


--
-- Name: host_host_id_seq; Type: SEQUENCE SET; Schema: public; Owner: genodo
--

SELECT pg_catalog.setval('host_host_id_seq', 15, true);


--
-- Data for Name: source; Type: TABLE DATA; Schema: public; Owner: genodo
--

COPY source (source_id, host_category_id, uniquename, displayname, description) FROM stdin;
1	1	stool	Stool	\N
2	1	urine	Urine	\N
3	1	colon	Colon	\N
4	1	ileum	Ileum	\N
5	1	cecum	Cecum	\N
6	1	intestine	Intestine	\N
7	1	blood	Blood	\N
8	1	liver	Liver	\N
9	1	cerebrospinal_fluid	cerebrospinal_fluid	\N
10	1	other	Other (fill in adjacent fields)	\N
11	2	feces	Feces	\N
12	2	urine	Urine	\N
13	2	meat	Meat	\N
14	2	blood	Blood	\N
15	2	liver	Liver	\N
16	2	intestine	Intestine	\N
17	2	other	Other (fill in adjacent fields)	\N
18	3	feces	Feces	\N
19	3	yolk	Yolk	\N
20	3	meat	Meat	\N
21	3	blood	Blood	\N
22	3	liver	Liver	\N
23	3	other	Other (fill in adjacent fields)	\N
24	4	veggiefood	Vegetable-based food	\N
25	4	meatfood	Meat-based food	\N
26	4	water	Water	\N
27	4	other	Other (fill in adjacent fields)	\N
29	2	colon	Colon	\N
30	2	cecum	Cecum	\N
31	1	urogenital	Urogenital system	\N
32	2	milk	Milk	\N
33	4	soil	Soil	\N
34	4	marine_sediment	Marine sediment	\N
\.


--
-- Name: source_source_id_seq; Type: SEQUENCE SET; Schema: public; Owner: genodo
--

SELECT pg_catalog.setval('source_source_id_seq', 34, true);


--
-- Data for Name: syndrome; Type: TABLE DATA; Schema: public; Owner: genodo
--

COPY syndrome (syndrome_id, host_category_id, uniquename, displayname, description) FROM stdin;
1	1	gastroenteritis	Gastroenteritis	\N
2	1	bloody_diarrhea	Bloody diarrhea	\N
3	1	hus	Hemolytic-uremic syndrome	\N
4	1	hc	Hemorrhagic colitis	\N
5	1	uti	Urinary tract infection (cystitis)	\N
6	1	crohns	Crohn's Disease	\N
7	1	uc	Ulcerateive colitis	\N
8	1	meningitis	Meningitis	\N
9	1	pneumonia	Pneumonia	\N
10	1	pyelonephritis	Pyelonephritis	\N
11	1	bacteriuria	Bacteriuria	\N
12	2	pneumonia	Pneumonia	\N
13	2	diarrhea	Diarrhea	\N
14	2	septicaemia	Septicaemia	\N
15	2	mastitis	Mastitis	\N
16	2	peritonitis	Peritonitis	\N
17	3	pneumonia	Pneumonia	\N
18	3	diarrhea	Diarrhea	\N
19	3	septicaemia	Septicaemia	\N
20	3	peritonitis	Peritonitis	\N
22	1	asymptomatic	Asymptomatic	\N
23	2	asymptomatic	Asymptomatic	\N
24	3	asymptomatic	Asymptomatic	\N
25	1	bacteremia	Bacteremia	\N
26	1	diarrhea	Diarrhea	\N
30	1	septicaemia	Septicaemia	\N
\.


--
-- Name: syndrome_syndrome_id_seq; Type: SEQUENCE SET; Schema: public; Owner: genodo
--

SELECT pg_catalog.setval('syndrome_syndrome_id_seq', 30, true);


--
-- PostgreSQL database dump complete
--


COMMIT;

