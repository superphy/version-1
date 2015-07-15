{
  'schema_class' => 'Database::Chado::Schema',
  'fixture_sets' => {
                      'miner' => [
                                   {
                                     'Host' => [
                                                 {
                                                   'uniquename' => 'hsapiens',
                                                   'scientificname' => 'Homo sapiens',
                                                   'host_category_id' => 1,
                                                   'host_id' => 1,
                                                   'commonname' => 'human',
                                                   'displayname' => 'Homo sapiens (human)'
                                                 },
                                                 {
                                                   'commonname' => 'cow',
                                                   'displayname' => 'Bos taurus (cow)',
                                                   'scientificname' => 'Bos taurus',
                                                   'uniquename' => 'btaurus',
                                                   'host_category_id' => 2,
                                                   'host_id' => 2
                                                 },
                                                 {
                                                   'commonname' => 'pig',
                                                   'displayname' => 'Sus scrofa (pig)',
                                                   'uniquename' => 'sscrofa',
                                                   'scientificname' => 'Sus scrofa',
                                                   'host_category_id' => 2,
                                                   'host_id' => 3
                                                 },
                                                 {
                                                   'host_category_id' => 2,
                                                   'host_id' => 4,
                                                   'uniquename' => 'mmusculus',
                                                   'scientificname' => 'Mus musculus',
                                                   'displayname' => 'Mus musculus (mouse)',
                                                   'commonname' => 'mouse'
                                                 },
                                                 {
                                                   'uniquename' => 'oaries',
                                                   'scientificname' => 'Ovis aries',
                                                   'host_category_id' => 2,
                                                   'host_id' => 5,
                                                   'commonname' => 'sheep',
                                                   'displayname' => 'Ovis aries (sheep)'
                                                 },
                                                 {
                                                   'host_category_id' => 3,
                                                   'host_id' => 6,
                                                   'scientificname' => 'Gallus gallus',
                                                   'uniquename' => 'ggallus',
                                                   'displayname' => 'Gallus gallus (chicken)',
                                                   'commonname' => 'chicken'
                                                 },
                                                 {
                                                   'commonname' => 'rabbit',
                                                   'displayname' => 'Oryctolagus cuniculus (rabbit)',
                                                   'uniquename' => 'ocuniculus',
                                                   'scientificname' => 'Oryctolagus cuniculus',
                                                   'host_id' => 7,
                                                   'host_category_id' => 2
                                                 },
                                                 {
                                                   'host_id' => 8,
                                                   'host_category_id' => 2,
                                                   'scientificname' => 'Canis lupus familiaris',
                                                   'uniquename' => 'clupus',
                                                   'displayname' => 'Canis lupus familiaris (dog)',
                                                   'commonname' => 'dog'
                                                 },
                                                 {
                                                   'commonname' => 'cat',
                                                   'displayname' => 'Felis catus (cat)',
                                                   'uniquename' => 'fcatus',
                                                   'scientificname' => 'Felis catus',
                                                   'host_category_id' => 2,
                                                   'host_id' => 9
                                                 },
                                                 {
                                                   'commonname' => 'environment',
                                                   'displayname' => 'Environmental source',
                                                   'scientificname' => 'Environmental source',
                                                   'uniquename' => 'environment',
                                                   'host_id' => 10,
                                                   'host_category_id' => 4
                                                 },
                                                 {
                                                   'host_category_id' => 2,
                                                   'host_id' => 11,
                                                   'scientificname' => 'User-specified Host',
                                                   'uniquename' => 'other',
                                                   'displayname' => 'Other (fill in adjacent fields)',
                                                   'commonname' => 'other'
                                                 }
                                               ]
                                   },
                                   {
                                     'Source' => [
                                                   {
                                                     'host_category_id' => 1,
                                                     'uniquename' => 'stool',
                                                     'displayname' => 'Stool',
                                                     'source_id' => 1,
                                                     'description' => undef
                                                   },
                                                   {
                                                     'uniquename' => 'urine',
                                                     'host_category_id' => 1,
                                                     'source_id' => 2,
                                                     'description' => undef,
                                                     'displayname' => 'Urine'
                                                   },
                                                   {
                                                     'displayname' => 'Colon',
                                                     'description' => undef,
                                                     'source_id' => 3,
                                                     'host_category_id' => 1,
                                                     'uniquename' => 'colon'
                                                   },
                                                   {
                                                     'displayname' => 'Ileum',
                                                     'description' => undef,
                                                     'source_id' => 4,
                                                     'host_category_id' => 1,
                                                     'uniquename' => 'ileum'
                                                   },
                                                   {
                                                     'host_category_id' => 1,
                                                     'uniquename' => 'cecum',
                                                     'displayname' => 'Cecum',
                                                     'description' => undef,
                                                     'source_id' => 5
                                                   },
                                                   {
                                                     'source_id' => 6,
                                                     'description' => undef,
                                                     'displayname' => 'Intestine',
                                                     'host_category_id' => 1,
                                                     'uniquename' => 'intestine'
                                                   },
                                                   {
                                                     'host_category_id' => 1,
                                                     'uniquename' => 'blood',
                                                     'source_id' => 7,
                                                     'description' => undef,
                                                     'displayname' => 'Blood'
                                                   },
                                                   {
                                                     'host_category_id' => 1,
                                                     'uniquename' => 'liver',
                                                     'source_id' => 8,
                                                     'description' => undef,
                                                     'displayname' => 'Liver'
                                                   },
                                                   {
                                                     'uniquename' => 'cerebrospinal_fluid',
                                                     'host_category_id' => 1,
                                                     'source_id' => 9,
                                                     'description' => undef,
                                                     'displayname' => 'cerebrospinal_fluid'
                                                   },
                                                   {
                                                     'uniquename' => 'other',
                                                     'host_category_id' => 1,
                                                     'description' => undef,
                                                     'source_id' => 10,
                                                     'displayname' => 'Other (fill in adjacent fields)'
                                                   },
                                                   {
                                                     'displayname' => 'Feces',
                                                     'description' => undef,
                                                     'source_id' => 11,
                                                     'host_category_id' => 2,
                                                     'uniquename' => 'feces'
                                                   },
                                                   {
                                                     'host_category_id' => 2,
                                                     'uniquename' => 'urine',
                                                     'displayname' => 'Urine',
                                                     'source_id' => 12,
                                                     'description' => undef
                                                   },
                                                   {
                                                     'displayname' => 'Meat',
                                                     'description' => undef,
                                                     'source_id' => 13,
                                                     'host_category_id' => 2,
                                                     'uniquename' => 'meat'
                                                   },
                                                   {
                                                     'description' => undef,
                                                     'source_id' => 14,
                                                     'displayname' => 'Blood',
                                                     'host_category_id' => 2,
                                                     'uniquename' => 'blood'
                                                   },
                                                   {
                                                     'source_id' => 15,
                                                     'description' => undef,
                                                     'displayname' => 'Liver',
                                                     'host_category_id' => 2,
                                                     'uniquename' => 'liver'
                                                   },
                                                   {
                                                     'displayname' => 'Intestine',
                                                     'source_id' => 16,
                                                     'description' => undef,
                                                     'host_category_id' => 2,
                                                     'uniquename' => 'intestine'
                                                   },
                                                   {
                                                     'displayname' => 'Other (fill in adjacent fields)',
                                                     'description' => undef,
                                                     'source_id' => 17,
                                                     'host_category_id' => 2,
                                                     'uniquename' => 'other'
                                                   },
                                                   {
                                                     'displayname' => 'Feces',
                                                     'source_id' => 18,
                                                     'description' => undef,
                                                     'host_category_id' => 3,
                                                     'uniquename' => 'feces'
                                                   },
                                                   {
                                                     'uniquename' => 'yolk',
                                                     'host_category_id' => 3,
                                                     'description' => undef,
                                                     'source_id' => 19,
                                                     'displayname' => 'Yolk'
                                                   },
                                                   {
                                                     'host_category_id' => 3,
                                                     'uniquename' => 'meat',
                                                     'description' => undef,
                                                     'source_id' => 20,
                                                     'displayname' => 'Meat'
                                                   },
                                                   {
                                                     'uniquename' => 'blood',
                                                     'host_category_id' => 3,
                                                     'description' => undef,
                                                     'source_id' => 21,
                                                     'displayname' => 'Blood'
                                                   },
                                                   {
                                                     'host_category_id' => 3,
                                                     'uniquename' => 'liver',
                                                     'displayname' => 'Liver',
                                                     'description' => undef,
                                                     'source_id' => 22
                                                   },
                                                   {
                                                     'displayname' => 'Other (fill in adjacent fields)',
                                                     'description' => undef,
                                                     'source_id' => 23,
                                                     'host_category_id' => 3,
                                                     'uniquename' => 'other'
                                                   },
                                                   {
                                                     'displayname' => 'Vegetable-based food',
                                                     'source_id' => 24,
                                                     'description' => undef,
                                                     'uniquename' => 'veggiefood',
                                                     'host_category_id' => 4
                                                   },
                                                   {
                                                     'uniquename' => 'meatfood',
                                                     'host_category_id' => 4,
                                                     'source_id' => 25,
                                                     'description' => undef,
                                                     'displayname' => 'Meat-based food'
                                                   },
                                                   {
                                                     'displayname' => 'Water',
                                                     'source_id' => 26,
                                                     'description' => undef,
                                                     'host_category_id' => 4,
                                                     'uniquename' => 'water'
                                                   },
                                                   {
                                                     'description' => undef,
                                                     'source_id' => 27,
                                                     'displayname' => 'Other (fill in adjacent fields)',
                                                     'host_category_id' => 4,
                                                     'uniquename' => 'other'
                                                   }
                                                 ]
                                   },
                                   {
                                     'Syndrome' => [
                                                     {
                                                       'host_category_id' => 1,
                                                       'uniquename' => 'gastroenteritis',
                                                       'displayname' => 'Gastroenteritis',
                                                       'syndrome_id' => 1,
                                                       'description' => undef
                                                     },
                                                     {
                                                       'description' => undef,
                                                       'syndrome_id' => 2,
                                                       'displayname' => 'Bloody diarrhea',
                                                       'uniquename' => 'bloody_diarrhea',
                                                       'host_category_id' => 1
                                                     },
                                                     {
                                                       'host_category_id' => 1,
                                                       'uniquename' => 'hus',
                                                       'description' => undef,
                                                       'syndrome_id' => 3,
                                                       'displayname' => 'Hemolytic-uremic syndrome'
                                                     },
                                                     {
                                                       'uniquename' => 'hc',
                                                       'host_category_id' => 1,
                                                       'syndrome_id' => 4,
                                                       'description' => undef,
                                                       'displayname' => 'Hemorrhagic colitis'
                                                     },
                                                     {
                                                       'syndrome_id' => 5,
                                                       'description' => undef,
                                                       'displayname' => 'Urinary tract infection (cystitis)',
                                                       'host_category_id' => 1,
                                                       'uniquename' => 'uti'
                                                     },
                                                     {
                                                       'syndrome_id' => 6,
                                                       'description' => undef,
                                                       'displayname' => 'Crohn\'s Disease',
                                                       'host_category_id' => 1,
                                                       'uniquename' => 'crohns'
                                                     },
                                                     {
                                                       'uniquename' => 'uc',
                                                       'host_category_id' => 1,
                                                       'displayname' => 'Ulcerateive colitis',
                                                       'syndrome_id' => 7,
                                                       'description' => undef
                                                     },
                                                     {
                                                       'host_category_id' => 1,
                                                       'uniquename' => 'meningitis',
                                                       'description' => undef,
                                                       'syndrome_id' => 8,
                                                       'displayname' => 'Meningitis'
                                                     },
                                                     {
                                                       'uniquename' => 'pneumonia',
                                                       'host_category_id' => 1,
                                                       'syndrome_id' => 9,
                                                       'description' => undef,
                                                       'displayname' => 'Pneumonia'
                                                     },
                                                     {
                                                       'description' => undef,
                                                       'syndrome_id' => 10,
                                                       'displayname' => 'Pyelonephritis',
                                                       'uniquename' => 'pyelonephritis',
                                                       'host_category_id' => 1
                                                     },
                                                     {
                                                       'description' => undef,
                                                       'syndrome_id' => 11,
                                                       'displayname' => 'Bacteriuria',
                                                       'host_category_id' => 1,
                                                       'uniquename' => 'bacteriuria'
                                                     },
                                                     {
                                                       'host_category_id' => 2,
                                                       'uniquename' => 'pneumonia',
                                                       'displayname' => 'Pneumonia',
                                                       'syndrome_id' => 12,
                                                       'description' => undef
                                                     },
                                                     {
                                                       'uniquename' => 'diarrhea',
                                                       'host_category_id' => 2,
                                                       'syndrome_id' => 13,
                                                       'description' => undef,
                                                       'displayname' => 'Diarrhea'
                                                     },
                                                     {
                                                       'syndrome_id' => 14,
                                                       'description' => undef,
                                                       'displayname' => 'Septicaemia',
                                                       'uniquename' => 'septicaemia',
                                                       'host_category_id' => 2
                                                     },
                                                     {
                                                       'uniquename' => 'mastitis',
                                                       'host_category_id' => 2,
                                                       'displayname' => 'Mastitis',
                                                       'description' => undef,
                                                       'syndrome_id' => 15
                                                     },
                                                     {
                                                       'host_category_id' => 2,
                                                       'uniquename' => 'peritonitis',
                                                       'syndrome_id' => 16,
                                                       'description' => undef,
                                                       'displayname' => 'Peritonitis'
                                                     },
                                                     {
                                                       'displayname' => 'Pneumonia',
                                                       'syndrome_id' => 17,
                                                       'description' => undef,
                                                       'host_category_id' => 3,
                                                       'uniquename' => 'pneumonia'
                                                     },
                                                     {
                                                       'displayname' => 'Diarrhea',
                                                       'description' => undef,
                                                       'syndrome_id' => 18,
                                                       'host_category_id' => 3,
                                                       'uniquename' => 'diarrhea'
                                                     },
                                                     {
                                                       'host_category_id' => 3,
                                                       'uniquename' => 'septicaemia',
                                                       'displayname' => 'Septicaemia',
                                                       'description' => undef,
                                                       'syndrome_id' => 19
                                                     },
                                                     {
                                                       'uniquename' => 'peritonitis',
                                                       'host_category_id' => 3,
                                                       'displayname' => 'Peritonitis',
                                                       'description' => undef,
                                                       'syndrome_id' => 20
                                                     }
                                                   ]
                                   },
                                   {
                                     'HostCategory' => [
                                                         {
                                                           'uniquename' => 'human',
                                                           'host_category_id' => 1,
                                                           'displayname' => 'Human'
                                                         },
                                                         {
                                                           'uniquename' => 'mammal',
                                                           'host_category_id' => 2,
                                                           'displayname' => 'Non-human Mammalia'
                                                         },
                                                         {
                                                           'uniquename' => 'bird',
                                                           'host_category_id' => 3,
                                                           'displayname' => 'Aves'
                                                         },
                                                         {
                                                           'host_category_id' => 4,
                                                           'uniquename' => 'env',
                                                           'displayname' => 'Environmental Sources'
                                                         }
                                                       ]
                                   }
                                 ]
                    },
  'resultsets' => [
                    'Host',
                    'Source',
                    'Syndrome',
                    'HostCategory'
                  ],
  'fixture_class' => '::Populate'
}
