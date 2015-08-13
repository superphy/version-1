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
	int s2 = 0;
	
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
		
		if(refseq[i] == '-') {
			// Gap col in ref
			
			if(seq[i] != '-') {
				// Nt col in comp
				// Block transition
				fprintf(fh2, "%i\t%i\t%i\t%i\t%i\t%i\n", s, s2, p, p2, g, g2);
				
				// Reset block counters
				s = p;
				s2 = p2;
				
				// Advance counters
				g2 = 0;
				p2++;
				
			} else {
				// Gap col in comp
				// No transition
				
				// Advance counters
				g2++;
			}
			
			// Advance counters
			g++;
			
		} else {
			// Nt col in ref
			
			if(seq[i] == '-') {
				// Gap col in comp
				// Block transition
				fprintf(fh2, "%i\t%i\t%i\t%i\t%i\t%i\n", s, s2, p, p2, g, g2);
				
				// Reset block counters
				s = p;
				s2 = p2;
				
				// Advance counters
				g2++;
				
			} else {
				// Nt col in comp
				
				if((g != 0 && g2 == 0) || (g == 0 && g2 != 0) {
					// Termination of gap in one sequence
					// Ignores gap columns
					// Block transition
					fprintf(fh2, "%i\t%i\t%i\t%i\t%i\t%i\n", s, s2, p, p2, g, g2);
					
					// Reset block counters
					s = p;
					s2 = p;
					
				}
				
				// Advance counters
				g2 = 0;
				p2++;
			}
	
			// Advance counters
			g = 0;
			p++;
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







MODULE = parallel_tree_builder_pl_cece	PACKAGE = main	

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

