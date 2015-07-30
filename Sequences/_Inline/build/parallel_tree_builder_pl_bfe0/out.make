Running Mkbootstrap for parallel_tree_builder_pl_bfe0 ()
chmod 644 parallel_tree_builder_pl_bfe0.bs
/usr/bin/perl /usr/share/perl/5.14/ExtUtils/xsubpp  -typemap "/usr/share/perl/5.14/ExtUtils/typemap"   parallel_tree_builder_pl_bfe0.xs > parallel_tree_builder_pl_bfe0.xsc && mv parallel_tree_builder_pl_bfe0.xsc parallel_tree_builder_pl_bfe0.c
cc -c  -I"/home/matt/workspace/a_genodo/sandbox/Sequences" -D_REENTRANT -D_GNU_SOURCE -DDEBIAN -fno-strict-aliasing -pipe -fstack-protector -I/usr/local/include -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -O2 -g   -DVERSION=\"0.00\" -DXS_VERSION=\"0.00\" -fPIC "-I/usr/lib/perl/5.14/CORE"   parallel_tree_builder_pl_bfe0.c
parallel_tree_builder_pl_bfe0.xs: In function ‘write_positions’:
parallel_tree_builder_pl_bfe0.xs:16:6: error: redefinition of ‘s’
parallel_tree_builder_pl_bfe0.xs:13:6: note: previous definition of ‘s’ was here
parallel_tree_builder_pl_bfe0.xs:42:49: error: ‘s2’ undeclared (first use in this function)
parallel_tree_builder_pl_bfe0.xs:42:49: note: each undeclared identifier is reported only once for each function it appears in
make: *** [parallel_tree_builder_pl_bfe0.o] Error 1
