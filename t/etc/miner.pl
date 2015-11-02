{
  'resultsets' => [
                    'HostCategory',
                    'Host',
                    'Source',
                    'Syndrome'
                  ],
  'fixture_class' => '::Populate',
  'schema_class' => 'Database::Chado::Schema',
  'fixture_sets' => {
                      'miner' => [
                                   {
                                     'HostCategory' => [
                                                         {
                                                           'displayname' => 'Human',
                                                           'host_category_id' => 1,
                                                           'uniquename' => 'human'
                                                         },
                                                         {
                                                           'host_category_id' => 2,
                                                           'uniquename' => 'mammal',
                                                           'displayname' => 'Non-human Mammalia'
                                                         },
                                                         {
                                                           'uniquename' => 'bird',
                                                           'host_category_id' => 3,
                                                           'displayname' => 'Aves'
                                                         },
                                                         {
                                                           'displayname' => 'Environmental Sources',
                                                           'uniquename' => 'env',
                                                           'host_category_id' => 4
                                                         }
                                                       ]
                                   },
                                   {
                                     'Host' => [
                                                 {
                                                   'displayname' => 'Homo sapiens (human)',
                                                   'commonname' => 'human',
                                                   'uniquename' => 'hsapiens',
                                                   'host_category_id' => 1,
                                                   'host_id' => 1,
                                                   'scientificname' => 'Homo sapiens'
                                                 },
                                                 {
                                                   'scientificname' => 'Bos taurus',
                                                   'host_id' => 2,
                                                   'uniquename' => 'btaurus',
                                                   'host_category_id' => 2,
                                                   'commonname' => 'cow',
                                                   'displayname' => 'Bos taurus (cow)'
                                                 },
                                                 {
                                                   'host_category_id' => 2,
                                                   'uniquename' => 'sscrofa',
                                                   'displayname' => 'Sus scrofa (pig)',
                                                   'commonname' => 'pig',
                                                   'scientificname' => 'Sus scrofa',
                                                   'host_id' => 3
                                                 },
                                                 {
                                                   'displayname' => 'Mus musculus (mouse)',
                                                   'commonname' => 'mouse',
                                                   'host_category_id' => 2,
                                                   'uniquename' => 'mmusculus',
                                                   'host_id' => 4,
                                                   'scientificname' => 'Mus musculus'
                                                 },
                                                 {
                                                   'scientificname' => 'Ovis aries',
                                                   'host_id' => 5,
                                                   'host_category_id' => 2,
                                                   'uniquename' => 'oaries',
                                                   'displayname' => 'Ovis aries (sheep)',
                                                   'commonname' => 'sheep'
                                                 },
                                                 {
                                                   'host_id' => 6,
                                                   'scientificname' => 'Gallus gallus',
                                                   'commonname' => 'chicken',
                                                   'displayname' => 'Gallus gallus (chicken)',
                                                   'uniquename' => 'ggallus',
                                                   'host_category_id' => 3
                                                 },
                                                 {
                                                   'host_category_id' => 2,
                                                   'uniquename' => 'ocuniculus',
                                                   'commonname' => 'rabbit',
                                                   'displayname' => 'Oryctolagus cuniculus (rabbit)',
                                                   'scientificname' => 'Oryctolagus cuniculus',
                                                   'host_id' => 7
                                                 },
                                                 {
                                                   'host_id' => 8,
                                                   'scientificname' => 'Canis lupus familiaris',
                                                   'displayname' => 'Canis lupus familiaris (dog)',
                                                   'commonname' => 'dog',
                                                   'host_category_id' => 2,
                                                   'uniquename' => 'clupus'
                                                 },
                                                 {
                                                   'host_id' => 9,
                                                   'scientificname' => 'Felis catus',
                                                   'displayname' => 'Felis catus (cat)',
                                                   'commonname' => 'cat',
                                                   'uniquename' => 'fcatus',
                                                   'host_category_id' => 2
                                                 },
                                                 {
                                                   'uniquename' => 'environment',
                                                   'host_category_id' => 4,
                                                   'displayname' => 'Environmental source',
                                                   'commonname' => 'environment',
                                                   'scientificname' => 'Environmental source',
                                                   'host_id' => 10
                                                 },
                                                 {
                                                   'host_category_id' => 2,
                                                   'uniquename' => 'other',
                                                   'commonname' => 'other',
                                                   'displayname' => 'Other (fill in adjacent fields)',
                                                   'scientificname' => 'User-specified Host',
                                                   'host_id' => 11
                                                 },
                                                 {
                                                   'host_id' => 13,
                                                   'scientificname' => 'Equus ferus caballus',
                                                   'displayname' => 'Equus ferus caballus (horse)',
                                                   'commonname' => 'horse',
                                                   'uniquename' => 'eferus',
                                                   'host_category_id' => 2
                                                 },
                                                 {
                                                   'displayname' => 'Capra aegagrus hircus (goat)',
                                                   'commonname' => 'goat',
                                                   'uniquename' => 'caegagrus',
                                                   'host_category_id' => 2,
                                                   'host_id' => 14,
                                                   'scientificname' => 'Capra aegagrus hircus'
                                                 },
                                                 {
                                                   'host_category_id' => 4,
                                                   'uniquename' => 'acepa',
                                                   'displayname' => 'Allium cepa (onion)',
                                                   'commonname' => 'onion',
                                                   'scientificname' => 'Allium cepa',
                                                   'host_id' => 15
                                                 },
                                                 {
                                                   'scientificname' => 'Meleagris',
                                                   'host_id' => 16,
                                                   'host_category_id' => 3,
                                                   'uniquename' => 'mgallopavo',
                                                   'displayname' => 'Meleagris gallopavo (turkey)',
                                                   'commonname' => 'turkey'
                                                 },
                                                 {
                                                   'host_id' => 17,
                                                   'scientificname' => 'Odocoileus',
                                                   'commonname' => 'deer',
                                                   'displayname' => 'Odocoileus sp. (deer)',
                                                   'host_category_id' => 2,
                                                   'uniquename' => 'odocoileus'
                                                 }
                                               ]
                                   },
                                   {
                                     'Source' => [
                                                   {
                                                     'description' => undef,
                                                     'displayname' => 'Stool',
                                                     'uniquename' => 'stool',
                                                     'host_category_id' => 1,
                                                     'source_id' => 1
                                                   },
                                                   {
                                                     'source_id' => 2,
                                                     'description' => undef,
                                                     'displayname' => 'Urine',
                                                     'uniquename' => 'urine',
                                                     'host_category_id' => 1
                                                   },
                                                   {
                                                     'source_id' => 3,
                                                     'host_category_id' => 1,
                                                     'uniquename' => 'colon',
                                                     'description' => undef,
                                                     'displayname' => 'Colon'
                                                   },
                                                   {
                                                     'description' => undef,
                                                     'displayname' => 'Ileum',
                                                     'host_category_id' => 1,
                                                     'uniquename' => 'ileum',
                                                     'source_id' => 4
                                                   },
                                                   {
                                                     'host_category_id' => 1,
                                                     'uniquename' => 'cecum',
                                                     'description' => undef,
                                                     'displayname' => 'Cecum',
                                                     'source_id' => 5
                                                   },
                                                   {
                                                     'description' => undef,
                                                     'displayname' => 'Intestine',
                                                     'uniquename' => 'intestine',
                                                     'host_category_id' => 1,
                                                     'source_id' => 6
                                                   },
                                                   {
                                                     'displayname' => 'Blood',
                                                     'description' => undef,
                                                     'host_category_id' => 1,
                                                     'uniquename' => 'blood',
                                                     'source_id' => 7
                                                   },
                                                   {
                                                     'source_id' => 8,
                                                     'host_category_id' => 1,
                                                     'uniquename' => 'liver',
                                                     'description' => undef,
                                                     'displayname' => 'Liver'
                                                   },
                                                   {
                                                     'source_id' => 9,
                                                     'host_category_id' => 1,
                                                     'uniquename' => 'cerebrospinal_fluid',
                                                     'description' => undef,
                                                     'displayname' => 'cerebrospinal_fluid'
                                                   },
                                                   {
                                                     'displayname' => 'Other (fill in adjacent fields)',
                                                     'description' => undef,
                                                     'uniquename' => 'other',
                                                     'host_category_id' => 1,
                                                     'source_id' => 10
                                                   },
                                                   {
                                                     'source_id' => 11,
                                                     'host_category_id' => 2,
                                                     'uniquename' => 'feces',
                                                     'displayname' => 'Feces',
                                                     'description' => undef
                                                   },
                                                   {
                                                     'host_category_id' => 2,
                                                     'uniquename' => 'urine',
                                                     'description' => undef,
                                                     'displayname' => 'Urine',
                                                     'source_id' => 12
                                                   },
                                                   {
                                                     'host_category_id' => 2,
                                                     'uniquename' => 'meat',
                                                     'description' => undef,
                                                     'displayname' => 'Meat',
                                                     'source_id' => 13
                                                   },
                                                   {
                                                     'source_id' => 14,
                                                     'displayname' => 'Blood',
                                                     'description' => undef,
                                                     'uniquename' => 'blood',
                                                     'host_category_id' => 2
                                                   },
                                                   {
                                                     'source_id' => 15,
                                                     'host_category_id' => 2,
                                                     'uniquename' => 'liver',
                                                     'description' => undef,
                                                     'displayname' => 'Liver'
                                                   },
                                                   {
                                                     'host_category_id' => 2,
                                                     'uniquename' => 'intestine',
                                                     'description' => undef,
                                                     'displayname' => 'Intestine',
                                                     'source_id' => 16
                                                   },
                                                   {
                                                     'source_id' => 17,
                                                     'description' => undef,
                                                     'displayname' => 'Other (fill in adjacent fields)',
                                                     'uniquename' => 'other',
                                                     'host_category_id' => 2
                                                   },
                                                   {
                                                     'source_id' => 18,
                                                     'uniquename' => 'feces',
                                                     'host_category_id' => 3,
                                                     'description' => undef,
                                                     'displayname' => 'Feces'
                                                   },
                                                   {
                                                     'uniquename' => 'yolk',
                                                     'host_category_id' => 3,
                                                     'description' => undef,
                                                     'displayname' => 'Yolk',
                                                     'source_id' => 19
                                                   },
                                                   {
                                                     'description' => undef,
                                                     'displayname' => 'Meat',
                                                     'uniquename' => 'meat',
                                                     'host_category_id' => 3,
                                                     'source_id' => 20
                                                   },
                                                   {
                                                     'uniquename' => 'blood',
                                                     'host_category_id' => 3,
                                                     'displayname' => 'Blood',
                                                     'description' => undef,
                                                     'source_id' => 21
                                                   },
                                                   {
                                                     'description' => undef,
                                                     'displayname' => 'Liver',
                                                     'uniquename' => 'liver',
                                                     'host_category_id' => 3,
                                                     'source_id' => 22
                                                   },
                                                   {
                                                     'host_category_id' => 3,
                                                     'uniquename' => 'other',
                                                     'displayname' => 'Other (fill in adjacent fields)',
                                                     'description' => undef,
                                                     'source_id' => 23
                                                   },
                                                   {
                                                     'source_id' => 24,
                                                     'displayname' => 'Vegetable-based food',
                                                     'description' => undef,
                                                     'host_category_id' => 4,
                                                     'uniquename' => 'veggiefood'
                                                   },
                                                   {
                                                     'description' => undef,
                                                     'displayname' => 'Meat-based food',
                                                     'uniquename' => 'meatfood',
                                                     'host_category_id' => 4,
                                                     'source_id' => 25
                                                   },
                                                   {
                                                     'displayname' => 'Water',
                                                     'description' => undef,
                                                     'uniquename' => 'water',
                                                     'host_category_id' => 4,
                                                     'source_id' => 26
                                                   },
                                                   {
                                                     'uniquename' => 'other',
                                                     'host_category_id' => 4,
                                                     'description' => undef,
                                                     'displayname' => 'Other (fill in adjacent fields)',
                                                     'source_id' => 27
                                                   },
                                                   {
                                                     'description' => undef,
                                                     'displayname' => 'Colon',
                                                     'host_category_id' => 2,
                                                     'uniquename' => 'colon',
                                                     'source_id' => 29
                                                   },
                                                   {
                                                     'displayname' => 'Cecum',
                                                     'description' => undef,
                                                     'uniquename' => 'cecum',
                                                     'host_category_id' => 2,
                                                     'source_id' => 30
                                                   },
                                                   {
                                                     'source_id' => 31,
                                                     'description' => undef,
                                                     'displayname' => 'Urogenital system',
                                                     'uniquename' => 'urogenital',
                                                     'host_category_id' => 1
                                                   },
                                                   {
                                                     'source_id' => 32,
                                                     'description' => undef,
                                                     'displayname' => 'Milk',
                                                     'uniquename' => 'milk',
                                                     'host_category_id' => 2
                                                   },
                                                   {
                                                     'description' => undef,
                                                     'displayname' => 'Soil',
                                                     'uniquename' => 'soil',
                                                     'host_category_id' => 4,
                                                     'source_id' => 33
                                                   },
                                                   {
                                                     'source_id' => 34,
                                                     'uniquename' => 'marine_sediment',
                                                     'host_category_id' => 4,
                                                     'description' => undef,
                                                     'displayname' => 'Marine sediment'
                                                   }
                                                 ]
                                   },
                                   {
                                     'Syndrome' => [
                                                     {
                                                       'description' => undef,
                                                       'displayname' => 'Gastroenteritis',
                                                       'uniquename' => 'gastroenteritis',
                                                       'host_category_id' => 1,
                                                       'syndrome_id' => 1
                                                     },
                                                     {
                                                       'description' => undef,
                                                       'displayname' => 'Bloody diarrhea',
                                                       'syndrome_id' => 2,
                                                       'host_category_id' => 1,
                                                       'uniquename' => 'bloody_diarrhea'
                                                     },
                                                     {
                                                       'syndrome_id' => 3,
                                                       'host_category_id' => 1,
                                                       'uniquename' => 'hus',
                                                       'displayname' => 'Hemolytic-uremic syndrome',
                                                       'description' => undef
                                                     },
                                                     {
                                                       'displayname' => 'Hemorrhagic colitis',
                                                       'description' => undef,
                                                       'uniquename' => 'hc',
                                                       'host_category_id' => 1,
                                                       'syndrome_id' => 4
                                                     },
                                                     {
                                                       'syndrome_id' => 5,
                                                       'host_category_id' => 1,
                                                       'uniquename' => 'uti',
                                                       'description' => undef,
                                                       'displayname' => 'Urinary tract infection (cystitis)'
                                                     },
                                                     {
                                                       'description' => undef,
                                                       'displayname' => 'Crohn\'s Disease',
                                                       'syndrome_id' => 6,
                                                       'uniquename' => 'crohns',
                                                       'host_category_id' => 1
                                                     },
                                                     {
                                                       'description' => undef,
                                                       'displayname' => 'Ulcerateive colitis',
                                                       'uniquename' => 'uc',
                                                       'host_category_id' => 1,
                                                       'syndrome_id' => 7
                                                     },
                                                     {
                                                       'displayname' => 'Meningitis',
                                                       'description' => undef,
                                                       'host_category_id' => 1,
                                                       'uniquename' => 'meningitis',
                                                       'syndrome_id' => 8
                                                     },
                                                     {
                                                       'displayname' => 'Pneumonia',
                                                       'description' => undef,
                                                       'syndrome_id' => 9,
                                                       'host_category_id' => 1,
                                                       'uniquename' => 'pneumonia'
                                                     },
                                                     {
                                                       'syndrome_id' => 10,
                                                       'host_category_id' => 1,
                                                       'uniquename' => 'pyelonephritis',
                                                       'displayname' => 'Pyelonephritis',
                                                       'description' => undef
                                                     },
                                                     {
                                                       'syndrome_id' => 11,
                                                       'uniquename' => 'bacteriuria',
                                                       'host_category_id' => 1,
                                                       'description' => undef,
                                                       'displayname' => 'Bacteriuria'
                                                     },
                                                     {
                                                       'host_category_id' => 2,
                                                       'uniquename' => 'pneumonia',
                                                       'syndrome_id' => 12,
                                                       'displayname' => 'Pneumonia',
                                                       'description' => undef
                                                     },
                                                     {
                                                       'description' => undef,
                                                       'displayname' => 'Diarrhea',
                                                       'uniquename' => 'diarrhea',
                                                       'host_category_id' => 2,
                                                       'syndrome_id' => 13
                                                     },
                                                     {
                                                       'uniquename' => 'septicaemia',
                                                       'host_category_id' => 2,
                                                       'syndrome_id' => 14,
                                                       'displayname' => 'Septicaemia',
                                                       'description' => undef
                                                     },
                                                     {
                                                       'uniquename' => 'mastitis',
                                                       'host_category_id' => 2,
                                                       'syndrome_id' => 15,
                                                       'displayname' => 'Mastitis',
                                                       'description' => undef
                                                     },
                                                     {
                                                       'displayname' => 'Peritonitis',
                                                       'description' => undef,
                                                       'syndrome_id' => 16,
                                                       'uniquename' => 'peritonitis',
                                                       'host_category_id' => 2
                                                     },
                                                     {
                                                       'displayname' => 'Pneumonia',
                                                       'description' => undef,
                                                       'host_category_id' => 3,
                                                       'uniquename' => 'pneumonia',
                                                       'syndrome_id' => 17
                                                     },
                                                     {
                                                       'host_category_id' => 3,
                                                       'uniquename' => 'diarrhea',
                                                       'syndrome_id' => 18,
                                                       'description' => undef,
                                                       'displayname' => 'Diarrhea'
                                                     },
                                                     {
                                                       'uniquename' => 'septicaemia',
                                                       'host_category_id' => 3,
                                                       'syndrome_id' => 19,
                                                       'description' => undef,
                                                       'displayname' => 'Septicaemia'
                                                     },
                                                     {
                                                       'displayname' => 'Peritonitis',
                                                       'description' => undef,
                                                       'syndrome_id' => 20,
                                                       'uniquename' => 'peritonitis',
                                                       'host_category_id' => 3
                                                     },
                                                     {
                                                       'displayname' => 'Asymptomatic',
                                                       'description' => undef,
                                                       'host_category_id' => 1,
                                                       'uniquename' => 'asymptomatic',
                                                       'syndrome_id' => 22
                                                     },
                                                     {
                                                       'description' => undef,
                                                       'displayname' => 'Asymptomatic',
                                                       'syndrome_id' => 23,
                                                       'host_category_id' => 2,
                                                       'uniquename' => 'asymptomatic'
                                                     },
                                                     {
                                                       'displayname' => 'Asymptomatic',
                                                       'description' => undef,
                                                       'host_category_id' => 3,
                                                       'uniquename' => 'asymptomatic',
                                                       'syndrome_id' => 24
                                                     },
                                                     {
                                                       'uniquename' => 'bacteremia',
                                                       'host_category_id' => 1,
                                                       'syndrome_id' => 25,
                                                       'description' => undef,
                                                       'displayname' => 'Bacteremia'
                                                     },
                                                     {
                                                       'displayname' => 'Diarrhea',
                                                       'description' => undef,
                                                       'uniquename' => 'diarrhea',
                                                       'host_category_id' => 1,
                                                       'syndrome_id' => 26
                                                     },
                                                     {
                                                       'host_category_id' => 1,
                                                       'uniquename' => 'septicaemia',
                                                       'syndrome_id' => 30,
                                                       'displayname' => 'Septicaemia',
                                                       'description' => undef
                                                     }
                                                   ]
                                   }
                                 ]
                    }
}
