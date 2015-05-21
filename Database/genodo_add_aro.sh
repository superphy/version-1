#!/bin/bash

stag-storenode.pl -d 'dbi:Pg:dbname="genodo";host="localhost";port=5432' --user postgres aro_obo_text.xml
