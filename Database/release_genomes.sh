#!/bin/bash

# SuperPhy/Genodo script

# This script is run daily to release private genomes
# to public that have passed their release date

DIR="/home/genodo/computational_platform/Database"

perl ${DIR}/genodo_release_private_genomes.pl --log /tmp/genodo_release_private_genomes.log --config ${DIR}/../Modules/genodo.cfg
