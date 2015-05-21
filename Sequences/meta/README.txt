Scripts for obtaining and loading NCBI sequences and meta data into Genodo DB

Steps:

1. ncbi_downloader.pl
Description: downloads FASTA files from NCBI for ecoli
Run with options:
	--ncbi wgs
	--terms escherichia%20coli
	--dir fasta_directory
	--log log_file 
followed by 
	--ncbi closed
	--terms "Eschericia coli"
	--dir data_directory
	--log log_file

2. chdir fasta_directory; ./get_file_names.sh
Description: Prints the filenames (minus the .fasta) for all fasta files 
downloaded in last step into file called file_names.txt

3. genbank_downloader.pl --dir genbank_directory --file_prefix file_names.txt
Description: Downloads all genbank files matching the fasta files.

4. fix_bioproject_ids.pl genbank_directory
Description: BioPerl cannot handle new BioProject IDs. Modifies ID so that it 
can be recognized by BioPerl parser.  Creates modified genbank files with 
suffix *_fixed.gbk

5. perl ../../genbank_bulk_loader.pl --fastadir fasta_directory
 --gbdir genbank_directory
 --configfile ../../../Modules/genodo.cfg 
 --logfile genbank_loading_log.txt
Description: loads all genomes into the database defined in the config file.


