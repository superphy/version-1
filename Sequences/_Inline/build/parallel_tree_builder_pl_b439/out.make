Running Mkbootstrap for parallel_tree_builder_pl_b439 ()
chmod 644 parallel_tree_builder_pl_b439.bs
/usr/bin/perl /usr/share/perl/5.14/ExtUtils/xsubpp  -typemap "/usr/share/perl/5.14/ExtUtils/typemap"   parallel_tree_builder_pl_b439.xs > parallel_tree_builder_pl_b439.xsc && mv parallel_tree_builder_pl_b439.xsc parallel_tree_builder_pl_b439.c
cc -c  -I"/home/matt/workspace/a_genodo/sandbox/Sequences" -D_REENTRANT -D_GNU_SOURCE -DDEBIAN -fno-strict-aliasing -pipe -fstack-protector -I/usr/local/include -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -O2 -g   -DVERSION=\"0.00\" -DXS_VERSION=\"0.00\" -fPIC "-I/usr/lib/perl/5.14/CORE"   parallel_tree_builder_pl_b439.c
parallel_tree_builder_pl_b439.xs: In function ‘write_positions’:
parallel_tree_builder_pl_b439.xs:43:67: error: expected ‘;’ before ‘if’
parallel_tree_builder_pl_b439.xs:70:67: error: expected ‘;’ before ‘if’
make: *** [parallel_tree_builder_pl_b439.o] Error 1
