{
  'schema_class' => 'Database::Chado::Schema',
  'fixture_class' => '::Populate',
  'fixture_sets' => {
                      'pipeline' => [
                                      {
                                        'Tracker' => [
                                                       {
                                                         'access_category' => 'public',
                                                         'failed' => 0,
                                                         'command' => undef,
                                                         'end_date' => '2015-08-21 23:04:11.784877',
                                                         'pid' => '1sKEZOxRU_',
                                                         'upload_id' => undef,
                                                         'feature_name' => 'Experimental strain Gamma-22',
                                                         'tracker_id' => 2,
                                                         'login_id' => 1,
                                                         'footprint' => '6bb0bd970c42010bd70cec531e1ac014',
                                                         'step' => 3,
                                                         'start_date' => '2015-08-21 16:14:18.619697'
                                                       }
                                                     ]
                                      },
                                      {
                                        'PipelineCache' => [
                                                             {
                                                               'collection_id' => 44,
                                                               'contig_id' => 45,
                                                               'chr_num' => 1,
                                                               'name' => 'gi|554510692|gb|CP006784.1|',
                                                               'description' => 'Escherichia coli JJ1886, complete genome',
                                                               'tracker_id' => 2
                                                             },
                                                             {
                                                               'tracker_id' => 2,
                                                               'name' => 'gi|554515525|gb|CP006785.1|',
                                                               'description' => 'Escherichia coli JJ1886 plasmid pJJ1886_1, complete sequence',
                                                               'chr_num' => 2,
                                                               'contig_id' => 46,
                                                               'collection_id' => 44
                                                             },
                                                             {
                                                               'contig_id' => 47,
                                                               'collection_id' => 44,
                                                               'tracker_id' => 2,
                                                               'name' => 'gi|554521644|gb|CP006786.1|',
                                                               'description' => 'Escherichia coli JJ1886 plasmid pJJ1886_2, complete sequence',
                                                               'chr_num' => 3
                                                             },
                                                             {
                                                               'chr_num' => 4,
                                                               'tracker_id' => 2,
                                                               'description' => 'Escherichia coli JJ1886 plasmid pJJ1886_3, complete sequence',
                                                               'name' => 'gi|554550476|gb|CP006787.1|',
                                                               'collection_id' => 44,
                                                               'contig_id' => 48
                                                             },
                                                             {
                                                               'chr_num' => 5,
                                                               'tracker_id' => 2,
                                                               'name' => 'gi|554587771|gb|CP006788.1|',
                                                               'description' => 'Escherichia coli JJ1886 plasmid pJJ1886_4, complete sequence',
                                                               'collection_id' => 44,
                                                               'contig_id' => 49
                                                             },
                                                             {
                                                               'chr_num' => 6,
                                                               'name' => 'gi|554590720|gb|CP006789.1|',
                                                               'description' => 'Escherichia coli JJ1886 plasmid pJJ1886_5, complete sequence',
                                                               'tracker_id' => 2,
                                                               'collection_id' => 44,
                                                               'contig_id' => 50
                                                             }
                                                           ]
                                      },
                                      {
                                        'PipelineStatus' => [
                                                              {
                                                                'status' => -1,
                                                                'starttime' => '2015-09-16 10:52:02.469697',
                                                                'name' => 'genodo_pipeline.pl-14323',
                                                                'job' => undef
                                                              },
                                                              {
                                                                'name' => 'genodo_pipeline.pl-14628',
                                                                'job' => undef,
                                                                'starttime' => '2015-09-16 11:04:21.331057',
                                                                'status' => -1
                                                              },
                                                              {
                                                                'job' => undef,
                                                                'name' => 'genodo_pipeline.pl-14147',
                                                                'status' => -1,
                                                                'starttime' => '2015-09-16 10:42:23.647988'
                                                              }
                                                            ]
                                      },
                                      {
                                        'PendingUpdate' => [
                                                             {
                                                               'job_input' => '$input = {\'g_host\' => \'mmusculus\',\'g_name\' => \'Experimental strain Gamma-22\',\'g_age_unit\' => \'years\',\'g_source\' => \'liver\',\'g_serotype\' => \'O48:H6\',\'g_date\' => \'2001-02-03\',\'g_strain\' => \'K1234\',\'g_mol_type\' => \'wgs\',\'g_privacy\' => \'private\',\'geocode_id\' => \'97\'};',
                                                               'upload_id' => 2,
                                                               'end_date' => '2015-09-16 11:12:06.043198',
                                                               'pending_update_id' => 5,
                                                               'failed' => 0,
                                                               'step' => 3,
                                                               'start_date' => '2015-09-14 14:25:34.143283',
                                                               'login_id' => 1,
                                                               'job_method' => 'update_genome_jm'
                                                             },
                                                             {
                                                               'pending_update_id' => 3,
                                                               'failed' => 0,
                                                               'end_date' => '2015-09-15 14:47:04.489786',
                                                               'upload_id' => 2,
                                                               'job_input' => '$input = {\'geocode_id\' => \'46\',\'g_host\' => \'ocuniculus\',\'g_age_unit\' => \'years\',\'g_date\' => \'2001-02-03\',\'g_source\' => \'liver\',\'g_mol_type\' => \'wgs\',\'g_privacy\' => \'public\',\'g_name\' => \'Experimental strain Gamma-22\',\'g_serotype\' => \'O48:H6\',\'g_strain\' => \'K1234\'};',
                                                               'login_id' => 1,
                                                               'job_method' => 'update_genome_jm',
                                                               'start_date' => '2015-08-27 14:01:20.555225',
                                                               'step' => 2
                                                             },
                                                             {
                                                               'step' => 2,
                                                               'start_date' => '2015-08-27 14:28:50.101711',
                                                               'job_method' => 'update_genome_jm',
                                                               'login_id' => 1,
                                                               'end_date' => '2015-09-15 14:47:04.489786',
                                                               'pending_update_id' => 4,
                                                               'failed' => 0,
                                                               'job_input' => '$input = {\'g_name\' => \'Experimental strain Gamma-22\',\'g_host\' => \'ocuniculus\',\'geocode_id\' => \'46\',\'g_mol_type\' => \'wgs\',\'g_age_unit\' => \'years\',\'g_date\' => \'2001-02-03\',\'g_strain\' => \'K1234\',\'g_privacy\' => \'private\',\'g_serotype\' => \'O48:H6\',\'g_source\' => \'liver\'};',
                                                               'upload_id' => 2
                                                             }
                                                           ]
                                      }
                                    ]
                    },
  'resultsets' => [
                    'Tracker',
                    'PipelineStatus',
                    'PendingUpdate'
                  ]
}
