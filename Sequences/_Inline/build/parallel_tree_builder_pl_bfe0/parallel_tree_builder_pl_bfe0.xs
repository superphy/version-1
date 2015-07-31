#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "INLINE.h"

void write_positions(char* refseq, char* seq, char* filename, char* filename2) {
	
	FILE* fh = fopen(filename, "w");
	FILE* fh2 = fopen(filename2, "w");
	int i;
	int g = 0; // gap
	int p = 0; // current position
	int s = 0; // start of alignment block
	int g2 = 0;
	int p2 = 0;
	int s = 0;
	
	// Alignment blocks are interupted by gaps
	// Gap columns are ignored
	// Alignment blocks are printed as
	// ref_start, seq_start, ref_end, seq_end, ref_gap_offset, seq_gap_offset
		
	if (fh == NULL) {
		fprintf(stderr, "Can't open output file %s!\n",
			filename);
		exit(1);
	}
	
	if (fh2 == NULL) {
		fprintf(stderr, "Can't open output file %s!\n",
			filename2);
		exit(1);
	}
	                                         
	for(i=0; refseq[i] && seq[i]; ++i) {
		
		// Advance reference sequence counters
		if(refseq[i] == '-') {
			
			if(seq[i] != '-') {
				// End of alignment block
				fprintf(fh2, "%i\t%i\t%i\t%i\t%i\t%i\n", s, s2, p, p2, g, g2);
			}
			
			g++;
			s = p;
			
		} else {
			
			if(g != 0) {
				// End of alignment block
				fprintf(fh2, "%i\t%i\t%i\t%i\t%i\t%i\n", s, s2, p, p2, g, g2);
				
				g = 0;
				s = p;
			}
			
			p++;
		}
		
		// Advance comparison sequence counters
		if(seq[i] == '-') {
			
			// End of alignment block
			fprintf(fh2, "%i\t%i\t%i\t%i\t%i\t%i\n", s, s2, p, p2, g, g2);
			
			g2++;
			s2 = p2;
			
	
		} else {
			
			if(g2 != 0) {
				// End of alignment block
				fprintf(fh2, "%i\t%i\t%i\t%i\t%i\t%i\n", s, s2, p, p2, g, g2);
				
				g2 = 0;
				s2 = p2;
			}
			
			p2++;
		}
		
		// Print SNP                                        
		if(refseq[i] != seq[i]) {
			fprintf(fh, "%i\t%i\t%c\t%c\n", p, g, refseq[i], seq[i]);
		}
		
		                                                                       
	}
	
	fclose(fh);                                                                           

}

void snp_positions(SV* seqs_arrayref, SV* names_arrayref, char* refseq, char* fileroot) {
	
	AV* names;
	AV* seqs;
	
	names = (AV*)SvRV(names_arrayref);
	seqs = (AV*)SvRV(seqs_arrayref);
	int n = av_len(seqs);
	int i;
	
	// compare each seq to ref
	// write snps to file for genome
	for(i=0; i <= n; ++i) {
		SV* name = av_shift(names);
		SV* seq = av_shift(seqs);
		char filename[120];
		char filename2[120];
		sprintf(filename, "%s__%s__snp_variations.txt", fileroot, (char*)SvPV_nolen(name));
		sprintf(filename2, "%s__%s__snp_positions.txt", fileroot, (char*)SvPV_nolen(name));
		
		write_positions(refseq, (char*)SvPV_nolen(seq), filename, filename2);
		
	}
	
}







MODULE = parallel_tree_builder_pl_bfe0	PACKAGE = main	

PROTOTYPES: DISABLE


void
write_positions (refseq, seq, filename, filename2)
	char *	refseq
	char *	seq
	char *	filename
	char *	filename2
	PREINIT:
	I32* temp;
	PPCODE:
	temp = PL_markstack_ptr++;
	write_positions(refseq, seq, filename, filename2);
	if (PL_markstack_ptr != temp) {
          /* truly void, because dXSARGS not invoked */
	  PL_markstack_ptr = temp;
	  XSRETURN_EMPTY; /* return empty stack */
        }
        /* must have used dXSARGS; list context implied */
	return; /* assume stack size is correct */

void
snp_positions (seqs_arrayref, names_arrayref, refseq, fileroot)
	SV *	seqs_arrayref
	SV *	names_arrayref
	char *	refseq
	char *	fileroot
	PREINIT:
	I32* temp;
	PPCODE:
	temp = PL_markstack_ptr++;
	snp_positions(seqs_arrayref, names_arrayref, refseq, fileroot);
	if (PL_markstack_ptr != temp) {
          /* truly void, because dXSARGS not invoked */
	  PL_markstack_ptr = temp;
	  XSRETURN_EMPTY; /* return empty stack */
        }
        /* must have used dXSARGS; list context implied */
	return; /* assume stack size is correct */

