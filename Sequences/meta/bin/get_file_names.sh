#!/bin/bash
# Needs to be run in fasta directory
ls -1 Esc* *.fasta | perl -e 's/\..+$//;' -p - > file_names.txt
