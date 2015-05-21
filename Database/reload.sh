#!/bin/bash
 
###########################
# Reload the genodo database
# with a saved copy
# Usage: reload.sh backupfile.sql
###########################

FILE=$1

if [ -z "$FILE" ]
then
    echo "No argument supplied. Must provide the filename containing te SQL dump."
fi

read -p "This will drop the current database. Are you sure you want to continue [y|N]? " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
	dropdb genodo
	createdb -T template0 genodo
	gunzip -c $1 | psql genodo
    exit 1
fi