#!/usr/bin/env R

tableData <- read.table(file='binary_table.txt', header=TRUE,sep="\t",row.names=1)
colSums(tableData)