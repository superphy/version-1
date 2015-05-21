Genodo PostgresDB Snapshots README
-----------------------------------

Directory contains dumps of the genodo db using the pg_dump tool.

1. genodo_chado_schema.sql
	Base Chado database. Only loaded with ontology data. Contains none of the additional tables created for genodo.

2. genodo_full_schema.sql
	Current db snapshot minus any genome data. Contains up-to-date schema with all additional tables as well as base data (i.e. ontologies).

3. create_login_tables.sql
	Schema for the login and sessions tables. Additions on top of base #1.
	
4. create_permission_tables.sql
	Schema for the permission, upload, private_feature, private_featureprop, private_feature_relationship and private_feature_dbxref
	tables. Additions on top of #3.
	
5. ../genodo_add_ontology.pl
	Add additional ontology terms used by Genodo to cvterm table (e.g. serotype, strain, isolation_host, etc.)
	
6. create_tracking_table.sql
	Schema for the tracker table (used to record progression of a uploaded genome being analyzed). Additions on top of #4.

7. create_deleted_upload_table.sql
	Schema for the deleted_upload table (used to record uploaded genomes that have been deleted by the user). Additions on top of #6.

8. data_tables.sql
	Schema for the amr, vf and locus data. Additions on top of #7.

9. ../genodo_add_db_urls.pl
	Add urlprefix fields for common DBs. Additions on top of #8

10. ../genodo_add_aro.sh
	Add antimicrobial resistance ontology to database using chadoXML file aro_obo_text.xml and DBIx::DBStag.
	
11. create_tree_table.sql
	Schema for storing tree strings. Additions on top of 10.
	
12. create_meta_table.sql
	Schema for storing meta data json strings. Additions on top of 11.
	
13. create_private_feature_tables.sql
	Schema for storing feature data (types, locations) for private genomes. Additions on top of 12.
