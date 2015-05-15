
DELETE FROM cvtermprop WHERE cvterm_id IN (SELECT cvterm.cvterm_id FROM cvterm JOIN cv ON cvterm.cv_id = cv.cv_id AND cv.cv_id = 16); 
DELETE FROM cvterm_relationship WHERE subject_id IN (SELECT cvterm.cvterm_id FROM cvterm JOIN cv on cvterm.cv_id = cv.cv_id AND cv.cv_id = 16);
DELETE FROM cvterm_dbxref WHERE cvterm_id IN (SELECT cvterm.cvterm_id FROM cvterm JOIN cv ON cvterm.cv_id = cv.cv_id AND cv.cv_id = 16);
DELETE FROM cvterm WHERE cv_id = 16 AND cvterm.dbxref_id IN (SELECT dbxref_id FROM dbxref);
DELETE FROM dbxref WHERE db_id IN (SELECT db_id FROM db WHERE db.name = 'VFDB');
DELETE FROM dbxref WHERE db_id IN (SELECT db_id FROM db WHERE db.name = 'VFO');
DELETE FROM db WHERE db.name = 'VFDB';

