\o pan_genome.fasta

SELECT f.feature_id, f.residues
FROM feature f, cvterm t1, cvterm t2, feature_cvterm ft
WHERE f.type_id = t1.cvterm_id AND t1.name = 'pangenome'
AND f.feature_id = ft.feature_id AND ft.cvterm_id = t2.cvterm_id
AND t2.name = 'core_genome' AND ft.is_not = FALSE;
\o
