Running Mkbootstrap for parallel_tree_builder_pl_73d3 ()
chmod 644 parallel_tree_builder_pl_73d3.bs
/usr/bin/perl /usr/share/perl/5.14/ExtUtils/xsubpp  -typemap "/usr/share/perl/5.14/ExtUtils/typemap"   parallel_tree_builder_pl_73d3.xs > parallel_tree_builder_pl_73d3.xsc && mv parallel_tree_builder_pl_73d3.xsc parallel_tree_builder_pl_73d3.c
cc -c  -I"/home/matt/workspace/a_genodo/sandbox/Sequences" -D_REENTRANT -D_GNU_SOURCE -DDEBIAN -fno-strict-aliasing -pipe -fstack-protector -I/usr/local/include -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -O2 -g   -DVERSION=\"0.00\" -DXS_VERSION=\"0.00\" -fPIC "-I/usr/lib/perl/5.14/CORE"   parallel_tree_builder_pl_73d3.c
parallel_tree_builder_pl_73d3.xs: In function ‘write_positions’:
parallel_tree_builder_pl_73d3.xs:112:4: error: invalid preprocessing directive #Print
make: *** [parallel_tree_builder_pl_73d3.o] Error 1
