#!/bin/bash
# My first script

perl Build.PL && ./Build && travis_wait ./Build test
npm i -g jasmine-node