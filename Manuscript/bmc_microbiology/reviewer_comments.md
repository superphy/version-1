MCRO-D-15-00461
SuperPhy: Predictive genomics for the bacterial pathogen Escherichia coli Chad Laing, PhD; Matthew D Whiteside, PhD; Akiff Manji; Peter Kruczkiewicz; Eduardo N Taboada, PhD; Victor PJ Gannon, PhD, DVM BMC Microbiology

Dear Dr. Laing,

Your manuscript "SuperPhy: Predictive genomics for the bacterial pathogen Escherichia coli" (MCRO-D-15-00461) has been assessed by our reviewers. Based on these reports, and my own assessment as Editor, I am pleased to inform you that it is potentially acceptable for publication in BMC Microbiology, once you have carried out some essential revisions suggested by our reviewers.

Their reports, together with any other comments, are below. In addition, please review the image quality of the figures submitted.  Please also take a moment to check our website at http://mcro.edmgr.com/ for any additional comments that were saved as attachments.

Once you have made the necessary corrections, please submit a revised manuscript online at:

http://mcro.edmgr.com/

If you have forgotten your username or password please use the "Send Login Details" link to get your login information. For security reasons, your password will be reset.

Please include a cover letter with a point-by-point response to the comments, describing any additional experiments that were carried out and including a detailed rebuttal of any criticisms or requested revisions that you disagreed with. Please also ensure that all changes to the manuscript are indicated in the text by highlighting or using track changes.

Please also ensure that your revised manuscript conforms to the journal style, which can be found at the Instructions for Authors on the journal homepage.

A decision will be made once we have received your revised manuscript, which we expect by 13 Dec 2015.

We look forward to receiving your revised manuscript and please do not hesitate to contact us if you have any questions.

Best wishes,

Brian Raphael
BMC Microbiology
http://www.biomedcentral.com/bmcmicrobiol

Reviewer reports:

### Reviewer #1: In general, I find the SuperPhy database to be a tool that will be useful to the E. coli community. I had problems making out the figure details in the PDF, but I did get a chance to use the online tool. Overall the interface is nice, although I did encounter some difficulties making it do exactly what I wanted and will likely require more practice. Prior to publication, the following minor, yet potentially important, changes should be made:
The figures have been modified to include panels, and zoomed sections where appropriate to highlight the relevant details in each figure. Additionally, two superfluous Figures were removed.


### L23: analyses to analytical?
We have made the suggested change.

### L116: Sentence looks like a run-on between "SNPs)" and "for"
The sentence "and determining statistically significant biomarkers (both the presence / absence of genomic regions and SNPs) for these group" has been changed to "and determining statistically significant biomarkers for these groups (both the presence / absence of genomic regions and SNPs)"

### L289: "gram" to "Gram"
We have now capitalized the term.

### L293-294: Don't know if 2005 should be considered a "recent" study
We have changed "Recent" to "Previous".

### L314-317: I would re-read this study. The point was to find E. coli regions that were not in Shigella, not to find E. coli targets that are not in other Escherichia genomes.
We agree that the point of the study was to find E. coli regions that were not in Shigella and vice-versa, and have clarified the text so that the work by Sahl et al., is not confused with the work of this study.
" The analyses performed in this study to find *E. coli* specific regions treated
 *Shigella spp.* as distinct from *E. coli*; had they been considered as
 sub-groups within *E. coli*, the number of species-specific markers
 would likely have increased."

 has been changed to

 " The analyses that we performed in the current study to find *E. coli* specific regions treated
  *Shigella spp.* as distinct from *E. coli*; had we considered them as
  sub-groups within *E. coli*, the number of species-specific markers
  would likely have increased."


### L318-L321: Did you consider the "cryptic" lineages of Escherichia in this analysis? If not, it might be worth looking into.
The 19 genomes reported in Table 2 were used to generate a candidate list of genomic regions that were potentially specific to the species E. coli (33 were identified). These 33 regions were screened against all the genomes in both the GenBank "nr" and "WGS" databases, where anything identified as *E. coli* was treated as such.
We are aware of the work by Walk et al. (Appl Environ Microbiol. 2009 Oct;75(20):6534-44. doi: 10.1128/AEM.01262-09) that originally identified the five cryptic clades of Escherichia, and more recent work by Luo et al. (Proc Natl Acad Sci U S A. 2011 Apr 26;108(17):7200-5. doi: 10.1073/pnas.1015622108.) that contributed the genome sequences of representatives of these cryptic lineages to GenBank. The Luo et al. (2011) work demonstrated extensive recombination among E. coli and E. cryptic clade 1, and argued they should be considered as E. coli. As the genomes of E. cryptic clade 1 in GenBank (TW15838 and TW10509) are labelled as Escherichia, but not E. coli, they and all the other cryptic Escherichia were included as genomes not possessing the E. coli specific regions.


### L378: Do you discuss a threshold on if a genome "possesses" the eae gene or not?
We do mention in the Materials and Methods section that all presence / absence distinctions are based on a sequence identity cutoff of 90% over the entire region. Additionally, we have separate sequences representing the different known subtypes of the *eae* gene in the database, which are identified at a 90% sequence identity threshold. The following has been changed to make this more clear:

"Within the 1641 genomes examined,
 662 possessed the *eae* gene."
 
 changed to
 
 "Within the 1641 genomes examined,
  662 possessed any of the 11 known variants of the *eae* gene at a sequence identity cutoff of 90%."


### Reviewer #2: SuperPhy appears to be a powerful and highly flexible online 'predictive genomics' platform for E. coli. It is unique from other online microbial genomics platforms in its integration of specialized information on E. coli pathogenesis and epidemiology and its user analysis features. I think the tool will be a valuable addition to the E. coli genomics community. I have only a few minor comments.

### 1) Website was slow/unresponsive at times I had several ERR_TIMED_OUT errors. If possible, consider moving the site to a different server. This could significantly improve its usability.
Our beta version of SuperPhy is currently hosted on a server shared by two other computational genomics programs; however, we have recently discussed hosting SuperPhy with its own dedicated resources on our national core facility server. This change is likely to take place in the next few months and will also increase the memory and number of processors available for the platform. 


### 2) ln 186 - "All genomes are considered to be E. coli if: 1) they contain at least 1500 conserved core regions, and 2) The presence of at least three E. coli species-specific regions." Is this a standard definition? If not, perhaps reword this more as a "quality check" than as species definition.
This is not a standard species definition, but based on our analyses of all the E. coli genomes in GenBank, it was found to be true. We do reference the reader to a more detailed explanation of these markers later in the manuscript, but to ensure there is no confusion we have changed the following sentence:  

"Uploaded genomes undergo two checks to ensure the data are of a minimum
 quality, and that the genomes being uploaded belong to the species *E.
 coli*." to
 
 "Uploaded genomes undergo two checks to ensure the data are of a minimum
  quality, and that the genomes being uploaded contain markers that were found to be present only in genomes of *E.
  coli*."


### 3) ln 245 "? The 'approximate' vectorized Fisher's Exact Test (FET) from the R corpora package is calculated (http://cran.r-project.org/web/packages/corpora/index.html), and the 100 most-significant results are then subject to the FET from the base R statistical package [35]. " First, are these p-values being corrected for multiple hypotheses? Second, perhaps specify that the 'approximate' FET is done (I'm assuming) simply for speed and the top results are then re-calculated using the exact test. This is not entirely clear.
Yes, these p-values are corrected for multiple-hypothesis testing using the false-discovery rate method of Benjamini and Hochberg. The reviewer is correct in the assumption that the "approximate" FET is conducted for speed, and the 100 most-significant results are then calculated using the exact FET method. To make this clear, we have changed the following:

"The statistical identification of markers that differ between groups
 based on both single nucleotide polymorphisms and the presence / absence
 of genomic loci is implemented using a two stage approach: 1) The
 ‘approximate’ vectorized Fisher's Exact Test (FET) from the R corpora
 package is calculated
 (<http://cran.r-project.org/web/packages/corpora/index.html>), and the
 100 most-significant results are then subject to the FET from the base R
 statistical package [@r_foundation_for_statistical_computing_r:_2005]."

to 

"The statistical identification of markers that differ between groups
 based on both single nucleotide polymorphisms and the presence / absence
 of genomic loci is implemented using a two stage approach: 1) To rapidly assess the thousands of possibilities, the
 ‘approximate’ vectorized Fisher's Exact Test (FET) from the R corpora
 package is calculated
 (<http://cran.r-project.org/web/packages/corpora/index.html>), following which the exact FET value is computed for the 100 most-significant results using the FET function from the base R
 statistical package [@r_foundation_for_statistical_computing_r:_2005]. The comparisons are corrected for multiple-testing using the false-discovery rate method of Benjamini and Hochberg."


--------------------
Editorial Requests
--------------------
Please note that all submissions to BMC Microbiology must comply with our editorial policies. Please read the following information and revise your manuscript as necessary. If your manuscript does not adhere to our editorial requirements this will cause a delay whilst the issue is addressed. Failure to adhere to our policies may result in rejection of your manuscript.

Ethics:
If your study involves humans, human data or animals, then your article should contain an ethics statement which includes the name of the committee that approved your study.
If ethics was not required for your study, then this should be clearly stated and a rationale provided.

Consent:
If your article is a prospective study involving human participants then your article should include a statement detailing consent for participation.
If individual clinical data is presented in your article, then you must clarify whether consent for publication of these data was obtained.

Availability of supporting data:
BioMed Central strongly encourages all data sets on which the conclusions of the paper rely be either deposited in publicly available repositories (where available and appropriate) or presented in the main papers or additional supporting files, in machine-readable format whenever possible. Authors must include an Availability of Data and Materials section in their article detailing where the data supporting their findings can be found. The Accession Numbers of any nucleic acid sequences, protein sequences or atomic coordinates cited in the manuscript must be provided and include the corresponding database name.

Authors Contributions:
Your 'Authors Contributions' section must detail the individual contribution for each individual author listed on your manuscript.


Further information about our editorial policies can be found at the following links:
Ethical approval and consent:
http://www.biomedcentral.com/about/editorialpolicies#Ethics
Standards of reporting:
http://www.biomedcentral.com/about/editorialpolicies#StandardsofReporting
Data availability:
http://www.biomedcentral.com/about/editorialpolicies#DataandMaterialRelease
