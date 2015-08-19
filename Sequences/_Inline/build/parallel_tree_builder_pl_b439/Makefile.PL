use ExtUtils::MakeMaker;
my %options = %{
{
  'TYPEMAPS' => [
    '/usr/share/perl/5.14/ExtUtils/typemap'
  ],
  'NAME' => 'parallel_tree_builder_pl_b439',
  'INC' => '-I"/home/matt/workspace/a_genodo/sandbox/Sequences"',
  'VERSION' => '0.00'
}
};
WriteMakefile(%options);

# Remove the Makefile dependency. Causes problems on a few systems.
sub MY::makefile { '' }
