#!/usr/bin/env perl

=pod

=head1 NAME

  Phylogeny::Tree

=head1 DESCRIPTION

  This class provides phylogenetic tree functions for maniputing and displaying
  trees in newick, perl-encoded and json format.

=head1 AUTHOR

  Matt Whiteside (mawhites@phac-aspc.gov.ca)

=cut

package Phylogeny::Tree;

use strict;
use warnings;

use File::Basename;
use lib dirname (__FILE__) . "/../";
use Carp qw/croak carp/;
use Role::Tiny::With;
with 'Roles::DatabaseConnector';
use Config::Simple;
use Data::Dumper;
use Log::Log4perl qw(:easy get_logger);
use JSON::MaybeXS;
use Modules::FormDataGenerator;
use List::Util qw/any/;

# Globals
my $visable_nodes; # temporary pointer to list of nodes to keep when pruning by recursion
my $short_circuit = 0; # boolean to stop subsequent recursion function calls
my $name_key = 'displayname';

=head2 new

Constructor

Required input parameter: config filename containing DB connection parameters
or pointer to existing DBIX::Class::Schema object.

=cut

sub new {
	my ($class) = shift;
	
	my $self = {};
	bless( $self, $class );
	
	my %params = @_;

	my $dbix = $params{dbix_schema};
	
	if($dbix) {
		# Use existing connection
		$self->setDbix($dbix);
		
	} 
	else {
		# Parse command-line options
		$self->connectDatabaseCL();
		
	}
	
	#Log::Log4perl->easy_init($DEBUG);
	
	return $self;
}


=head2 loadTree

Called after each time a new phylogenetic tree is built. Performs the following
functions:

  1. parses newick string into perl-encoded data structure
  2. saves perl-encoded tree as "global" in DB
  3. prunes tree into only those visable by public, converts to json and saves as "public" in DB

=cut

sub loadTree {
	my ($self, $newick_file) = @_;
	
	# Parse newick tree
	my $ptree = $self->newickToPerl($newick_file);
	
	$self->loadPerlTree($ptree);

}

=head2 loadPerlTree

See loadTree. Adds ability to load a perl-language
tree.

=cut

sub loadPerlTree {
	my ($self, $ptree) = @_;
	
	# Save entire tree in database as Data::Dumper perl structure
	$Data::Dumper::Indent = 0;
	my $ptree_string = Data::Dumper->Dump([$ptree], ['tree']);
	
	$self->dbixSchema->resultset('Tree')->update_or_create(
		{
			name             => 'global',
			format           => 'perl',
			tree_string      => $ptree_string,
			timelastmodified => \'now()'
		},
		{
			key => 'tree_c1'
		}
	);
	
	# Remove any private genomes
	my $public_list = $self->visableGenomes;
	
	# Prune private genomes from tree
	my $public_tree = $self->prepTree($ptree, $public_list, 0);
	
	# Save perl copy for instances where we need to do some editing
	my $ptree_string2 = Data::Dumper->Dump([$public_tree], ['tree']);
	
	$self->dbixSchema->resultset('Tree')->update_or_create(
		{
			name             => 'perlpub',
			format           => 'perl',
			tree_string      => $ptree_string2,
			timelastmodified => \'now()'
		},
		{
			key => 'tree_c1'
		}
	);
	
	# Convert to json
	my $jtree_string = encode_json($public_tree);
	
	# Save in DB
	$self->dbixSchema->resultset('Tree')->update_or_create(
		{
			name             => 'jsonpub',
			format           => 'json',
			tree_string      => $jtree_string,
			timelastmodified => \'now()'
		},
		{
			key => 'tree_c1'
		}
	);

}

=head2 prepTree

	Trim non-visable nodes. Collapse nodes above certain depth.
	In the D3 tree library, to collapse a node, the children array is
	renamed to _children.

=cut

sub prepTree {
	my ($self, $root, $nodes, $restrict_depth) = @_;
	
	# Set global
	$visable_nodes = $nodes;
	
	$root->{'length'} = 0;
	
	my ($updated_tree, $discard) = _pruneNodeRecursive($root, 0, $restrict_depth, 0);
	
	return $updated_tree;
}

sub _pruneNodeRecursive {
	my ($node, $depth, $restrict_depth, $parent_length) = @_;
	
	$depth++;
	$node->{sum_length} = $node->{'length'} + $parent_length;
	
	if($node->{children}) {
		# Internal node
		
		# Find visable descendent nodes
		my @visableNodes;
		my @nodeRecords;
		foreach my $childnode (@{$node->{children}}) {
			my ($visableNode, $nodeRecord) = _pruneNodeRecursive($childnode, $depth, $restrict_depth, $node->{sum_length});
			if($visableNode) {
				push @visableNodes, $visableNode;
				push @nodeRecords, $nodeRecord;
			}
		}
		
		# Finished recursion
		# Transform internal node if needed
		
		if(@visableNodes > 1) {
			# Update children, length unchanged
			
			my $record;
			
			# Make informative label for internal node
			my $num_leaves = 0;
			my $outg_label;
			my $outg_length;
			my $outg_depth;
			foreach my $child (@nodeRecords) {
				$num_leaves += $child->{num_leaves};
				if($outg_label) {
					# Compare to existing outgroup
					if($outg_depth > $child->{depth} || ($outg_depth == $child->{depth} && $outg_length < $child->{'length'})) {
						# new outgroup found
						$outg_label = $child->{outgroup};
						$outg_depth = $child->{depth};
						$outg_length = $child->{'length'};
					}
				} else {
					$outg_label = $child->{outgroup};
					$outg_depth = $child->{depth};
					$outg_length = $child->{'length'};
				}
			}
			
			$node->{label} = "$num_leaves genomes (outgroup: $outg_label)";
			
			$record->{num_leaves} = $num_leaves;
			$record->{depth} = $outg_depth;
			$record->{'length'} = $outg_length;
			$record->{outgroup} = $outg_label;
			
			if($restrict_depth && $depth > 8) {
				# Collapse all nodes above a certain depth
				
				delete $node->{children};
				$node->{_children} = \@visableNodes;
				
			} else {
				$node->{children} = \@visableNodes;
			}
			
			return ($node, $record); # record is empty unless $restrict_depth is true
			
		} elsif(@visableNodes == 1) {
			# No internal node needed, replace with singleton child node
			# Sum lengths
			my $replacementNode = shift @visableNodes;
			$replacementNode->{'length'} += $node->{'length'};
			my $newRecord = shift @nodeRecords;
			$newRecord->{depth}--;
			$newRecord->{'length'} = $replacementNode->{'length'};
			return ($replacementNode, $newRecord);
		} else {
			# Empty node, remove
			return;
		}
		
	} else {
		# Leaf node
		
		my $name = $node->{name};
		croak "Leaf node with no defined name at depth $depth.\n" unless $name;
		if($name =~ m/^upl_/) {
			get_logger->warn("SERIOUS BUG DETECTED! genome node in tree contains a temporary ID and will be omitted from pruned tree. Tree needs to be reloaded to correct. ");
			return;
		}
		my ($access, $genomeId) = ($name =~ m/^(public|private)_(\d+)/);
		croak "Leaf node name $name does not contain valid genome ID at depth $depth.\n" unless $access && $genomeId;
		
		my $genome_name = "$access\_$genomeId";
		
		if($visable_nodes->{$genome_name}) {
			my $label = $visable_nodes->{$genome_name}->{$name_key};
			# Add a label to the leaf node
			$node->{label} = $label;
			$node->{leaf} = 'true';
			my $record;
			$record->{num_leaves} = 1;
			$record->{outgroup} = $label;
			$record->{depth} = $depth;
			$record->{'length'} = $node->{'length'};
			return ($node, $record);
		} else {
			
			return;
		}
	}
	
}

=head2 blowUpPath

Expand nodes along path from target leaf node
to root.

=cut

sub blowUpPath {
	my ($curr, $target, $path) = @_;
	
	
	# Children in collapsed or expanded nodes
	my @children;
	if($curr->{children}) {
		@children = @{$curr->{children}};
	} elsif($curr->{_children}) {
		@children = @{$curr->{_children}}
	}
	
	if(@children && !$short_circuit) {
		my @new_path = @$path;
		push @new_path, $curr;
		
		foreach my $child (@children) {
			blowUpPath($child, $target, \@new_path);
		}
		
	} else {
		# Is this the leaf node we are looking for?
		if($curr->{name} eq $target) {
			# Exand nodes along path to root
			
			$curr->{focus} = 1; # Change style of node
			
			$short_circuit = 1; # Stop future recursion calls
			
			foreach my $path_node (@$path) {
				if($path_node->{_children}) {
					$path_node->{children} = $path_node->{_children};
					delete $path_node->{_children};
				}
			}
		}
	}
	
}


=head2 userTree

Return json string of phylogenetic visable to user

Input is a hash of valid feature_IDs.

=cut

sub userTree {
	my ($self, $visable) = @_;
	
	# Get tree perl hash-ref
	my $ptree = $self->globalTree;
	
	# Remove genomes not visable to user
	my $user_tree = $self->prepTree($ptree, $visable);
	
	# Convert to json
	my $jtree_string = encode_json($user_tree);
	
	return $jtree_string;
}

=head2 publicTree

Return json string of phylogenetic visable to all users

=cut

sub publicTree {
	my $self = shift;
	
	my $tree_rs = $self->dbixSchema->resultset("Tree")->search(
		{
			name => 'jsonpub'	
		},
		{
			columns => ['tree_string']
		}
	);
	
	return $tree_rs->first->tree_string;	
}

=head2 globalTree

Return perl data-structure phylogenetic containing all nodes (INCLUDING PRIVATE!!)

Returns a perl hash-ref and not a string.

=cut

sub globalTree {
	my $self = shift;
	
	my $tree_rs = $self->dbixSchema->resultset("Tree")->search(
		{
			name => 'global'	
		},
		{
			columns => ['tree_string']
		}
	);
	
	# Tree hash is saved as $tree in Data::Dumper string
	my $tree;
	
	eval $tree_rs->first->tree_string;
	
	return $tree;	
}

=head2 perlPublicTree

Return perl data-structure phylogenetic containing only public genomes

Returns a perl hash-ref and not a string.

=cut

sub perlPublicTree {
	my $self = shift;
	
	my $tree_rs = $self->dbixSchema->resultset("Tree")->search(
		{
			name => 'perlpub'	
		},
		{
			columns => ['tree_string']
		}
	);
	
	# Tree hash is saved as $tree in Data::Dumper string
	my $tree;
	
	eval $tree_rs->first->tree_string;
	
	return $tree;	
}

=head2 fullTree

Returns json string representing "broad" view of tree.

Nodes are all collapsed above a certain depth.

=cut
sub fullTree {
	my ($self, $visable) = @_;
	
	if($visable) {
		return $self->userTree($visable);
	} else {
		return $self->publicTree();
	}
}

=head2 nodeTree

Returns json string of tree.

NOTE: Nodes are NO LONGER collapsed above a certain depth. This is done on
the fly using javascript.

=cut

sub nodeTree {
	my ($self, $node, $visable) = @_;
	
	if($visable) {
		# User has private genomes
		my $ptree = $self->globalTree;
	
		# Remove genomes not visable to user
		my $tree = $self->prepTree($ptree, $visable, 0);
		
		# Exand nodes along path to target leaf node
		DEBUG encode_json($tree);
		
		blowUpPath($tree, $node, []);
		
		# Convert to json
		my $jtree_string = encode_json($tree);
		
		return $jtree_string;
		
	} else {
		# User can only view public genomes
		my $tree = $self->perlPublicTree;
	
		# Exand nodes along path to target leaf node
		blowUpPath($tree, $node, []);
		
		# Convert to json
		my $jtree_string = encode_json($tree);
		
		return $jtree_string;
	}
}

=cut newick_to_perl

Convert from Newick to Perl structure.

Input: file name containing Newick string
Returns: hash-ref

=cut

sub newickToPerl {
	my $self = shift;
	my $newick_file = shift;
	
	my $newick;
	open(IN, "<$newick_file") or croak "Error: unable to read file $newick_file ($!)\n";
	
	while(my $line = <IN>) {
		chomp $line;
		$newick .= $line;
	}
	
	close IN;
	
	my @tokens = split(/\s*(;|\(|\)|:|,)\s*/, $newick);
	my @ancestors;
	my $tree = {};
	
	for(my $i=0; $i < @tokens; $i++) {
		
		my $tok = $tokens[$i];
		
		if($tok eq '(') {
			my $subtree = {};
			$tree->{children} = [$subtree];
			push @ancestors, $tree;
			$tree = $subtree;
			
		} elsif($tok eq ',') {
			my $subtree = {};
			push @{$ancestors[$#ancestors]->{children}}, $subtree;
			$tree = $subtree;
			
		} elsif($tok eq ')') {
			$tree = pop @ancestors;
			
		} elsif($tok eq ':') {
			# optional length next
			
		} else {
			my $x = $tokens[$i-1];
        	
        	if( $x eq ')' || $x eq '(' || $x eq ',') {
				$tree->{name} = $tok;
				$tree->{'length'} = 0; # Initialize to 0
          	} elsif ($x eq ':') {
          		$tree->{'length'} = 0+$tok;  # Force number
          	}
		}
	}
	
	return $tree;
}

=cut visableGenomes

Get all public genomes for any user.

This is meant to be called outside of normal website operations, specifically
when a new phylogenetic tree is being loaded.  Visable genomes for a user will be computed
using FormDataGenerator during website queries and should be used instead of repeating 
the same query in this method again.

=cut

sub visableGenomes {
	my ($self) = @_;
	
	# Get public genomes
	my $data = Modules::FormDataGenerator->new;
	$data->dbixSchema($self->dbixSchema);
	
	my %visable;
	$data->publicGenomes(\%visable);
	
	$data->privateGenomes(undef, \%visable);

	return \%visable;
}

sub newickToPerlString {
	my $self = shift;
	my $newick_file = shift;
	
	my $ptree = $self->newickToPerl($newick_file);
	
	$Data::Dumper::Indent = 0;
	my $ptree_string = Data::Dumper->Dump([$ptree], ['tree']);
	
	return $ptree_string;
}

=head2 geneTree

=cut

sub geneTree {
	my $self = shift;
	my $gene_id = shift;
	my $public = shift;
	my $visable = shift;
	
	# Retrieve gene tree
	my $table = 'feature_trees';
	$table = 'private_feature_trees' unless $public;
	
	my $tree_rs = $self->dbixSchema->resultset("Tree")->search(
		{
			"$table.feature_id" => $gene_id	
		},
		{
			join => [$table],
			columns => ['tree_string']
		}
	);
	
	my $tree_row = $tree_rs->first;
	unless($tree_row) {
		get_logger->info( "[Warning] no entry in tree table mapped to feature ID: $gene_id\n");
		return undef;
	}
	
	# Tree hash is saved as $tree in Data::Dumper string
	my $tree;
	eval $tree_row->tree_string;
	
#	{
#		$Data::Dumper::Indent = 1;
#		$Data::Dumper::Sortkeys = 1;
#		get_logger->debug(Dumper $tree);
#		
#	}
	
	# Remove genomes not visable to user
	my $user_tree = $self->prepTree($tree, $visable);
	
	# Convert to json
	my $jtree_string = encode_json($user_tree);
	
	return $jtree_string;
}

=head2 pairwise_distances

Args:
1. file name containg nt MSA in FASTA format
2. file name for newick tree output

=cut

sub pairwise_distances {
	my ($self, $msa_file, $tree_file) = @_;
	
	my $cmd = join(' ', $self->cc_exe, $self->cc_opt, '<', $msa_file, '>', $tree_file);
	
	unless(system($cmd) == 0) {
		die "clearcut error ($!).\n";
		return 0;
	}
	
	return(1);
}

=head2 find_lca

Given a set of leaf nodes, find the lowest (or most recent) common ancestor internal node

Args:
1. A hash reference representing internal node in PERL-based tree
2. Array of strings that match the 'name' value in leaf nodes

=cut

sub find_lca {
	my $self = shift;
	my $root = shift;
	my @targetNodes = @_;
	
	my %targets;
	map { $targets{$_} = 1 } @targetNodes;

	my $subtreeNode = _recursive_lca($root, \%targets);

	foreach my $n (keys %targets) {
		if($targets{$n} < 2) {
			my $msg = "WARNING: $n leaf node not found in traversal. LCA may be incorrect.\n";
			carp $msg;
			get_logger->warn($msg);
		}
	}

	return($subtreeNode);
}

sub _recursive_lca {
	my $root = shift;
	my $targets = shift;

	# Check if one of our target nodes is a descendent
	# If yes, then this root is the LCA
	if($root->{children}) {
		my $descendent = 0;
		my @internals;
		foreach my $c (@{$root->{children}}) {
			if($c->{children}) {
				push @internals, $c;
			} else {
				if($targets->{$c->{name}}) {
					# Found target node
					$targets->{$c->{name}}++;
					return $root;
				}
			}
		}

		# Check subtrees for LCA
		# If targets scattered over multiple subtrees
		# then this root is the LCA
		my @subtrees;
		foreach my $i (@internals) {
			my $s = _recursive_lca($i, $targets);
			push @subtrees, $s if $s;

			if(@subtrees > 1) {
				return $root;
			}
		}

		# The LCA is in this one subtree
		if(@subtrees) {
			return $subtrees[0];
		}
	}
	
	# LCA not found in this branch
	return 0;
}


=head2 find_leaves

Given a single internal node, return all descendant leaves

Args:
1. A hash reference representing internal node in PERL-based tree
2. A boolean indicating weather to include length from root. Each leaf node
will be in array

=cut

sub find_leaves {
	my $self = shift;
	my $root = shift;
	my $len = shift;

	$len = $len // 0;
	$root->{length} = $root->{length} // 0;
	my $tot_len = $root->{length}+$len;

	if($root->{children}) {
		my @leaves;
		foreach my $c (@{$root->{children}}) {
			push @leaves, $self->find_leaves($c, $tot_len);
		}

		return @leaves;

	} else {
		return { node => $root, len => $tot_len };
		
	}
}

=head2 snpAlignment

Retrieves snp alignment

Args:
A hash with the following optional keys:
1. file => output file name. If not provided a hash-ref is returned with alignment strings
2. genomes => the subset of genomes to retrieve snp alignments for. If not provided, all genomes used.

Returns:
hashref of genome_name => alignment (provided, file argument is not used)

=cut

sub snpAlignment {
	my $self = shift;
	my %args = @_;


	my $conds = {};

	if($args{genomes}) {
		croak "Invalid argument. Proper usage: genomes => arrayref.\n" unless ref($args{genomes}) eq 'ARRAY';
		$conds->{name} = {'-in' => $args{genomes}};
	}

	my $table = "SnpAlignment";
	if($args{temp_table}) {
		$table = $args{temp_table}
	}

	my $aln_rs = $self->dbixSchema->resultset($table)->search(
		$conds,
		{
			columns => [qw/name alignment/]
		}
	);

	if($args{genomes} && (scalar(@{$args{genomes}}) != $aln_rs->count())) {
		warn "Error: one or more requested genomes not found in the snp_alignment table (requested: ".scalar(@{$args{genomes}}).
			", found: ".$aln_rs->count().").\n";
		my %check;
		my $n = 0;
		map { $check{$_} = 0 } @{$args{genomes}};
		while(my $aln_row = $aln_rs->next) {
			$check{$aln_row->name} = 1;
			$n++;
		}
		foreach my $g (keys %check) {
			warn "Genome $g not found\n" unless $check{$g};
		}
		croak "$n"
	}

	my %alignment;
	my $print = ($args{file}) ? 1 : 0;
	my $out;
	if($print) {
		open($out, '>'.$args{file}) or croak "Error: unable to write to file $args{file} ($!).\n";
	}

	while(my $aln_row = $aln_rs->next) {
		my $nm = $aln_row->name;
		next if $nm eq 'core';
		if($print) {
			print $out ">$nm\n".$aln_row->alignment."\n";
		} else {
			$alignment{$nm} = $aln_row->alignment;
		}
		
	}

	if($print) {
		close $out;
	} else {
		return \%alignment;
	}
}

=head2 pgAlignment

Retrieves pangenome core presence/absence alignment.
T = present
A = absent

Args:
A hash with the following optional keys:
1. file => output file name. If not provided a hash-ref is returned with alignment strings
2. genomes => the subset of genomes to retrieve snp alignments for. If not provided, all genomes used.
3. core => 1, uses only core region string, otherwise entire pangenome is used
4. accessory => 1, uses only accessory region string, otherwise entire pangenome is used

Returns:
hashref of genome_name => alignment (provided, file argument is not used)

=cut

sub pgAlignment {
	my $self = shift;
	my %args = @_;


	my $conds = {};

	if($args{genomes}) {
		croak "Invalid argument. Proper usage: genomes => arrayref.\n" unless ref($args{genomes}) eq 'ARRAY';
		$conds->{name} = {'-in' => $args{genomes}};
	}

	if($args{omit}) {
		croak "Invalid argument. Proper usage: omit => arrayref.\n" unless ref($args{omit}) eq 'ARRAY';
		$conds->{name} = {'-not_in' => $args{omit}};
	}

	my $table = "PangenomeAlignment";
	if($args{temp_table}) {
		$table = $args{temp_table}
	}

	my @columns = qw/name/;
	if($args{core}) {
		push @columns, { alignment => 'core_alignment' };
	} elsif($args{accessory}) {
		push @columns, { alignment => 'acc_alignment' };
	} else {
		push @columns, { alignment => \'concat(core_alignment, acc_alignment)'};
	}

	my $aln_rs = $self->dbixSchema->resultset($table)->search(
		$conds,
		{
			columns => \@columns
		}
	);

	if($args{genomes} && scalar(@{$args{genomes}}) != $aln_rs->count()) {
		croak "Error: requested genomes not found in the snp_alignment table (genomes: ".join(', ', @{$args{genomes}}).").\n";
	}

	my %alignment;
	my $print = ($args{file}) ? 1 : 0;
	my $out;
	if($print) {
		open($out, '>'.$args{file}) or croak "Error: unable to write to file $args{file} ($!).\n";
	}

	while(my $aln_row = $aln_rs->next) {
		my $nm = $aln_row->name;
		next if $nm eq 'core';
		my $aln = $aln_row->get_column('alignment');
		$aln =~ tr/01/AT/;
		if($print) {
			print $out ">$nm\n$aln\n";
		} else {
			$alignment{$nm} = $aln;
		}
		
	}

	if($print) {
		close $out;
	} else {
		return \%alignment;
	}
}

=head2 compareTrees

0 = equal
1 = different

Checks if identical leaf labels are found in same level / branch in traversal of tree
e.g. isomorphic

Assumes root nodes have children

=cut
sub compareTrees {
	my $self  = shift;
	my $treeA = shift;
	my $treeB = shift;

	my @levela = ($treeA);
	my @levelb = ($treeB);
	my @nextlevela;
	my @nextlevelb;
	my %leafa;

	while(@levela && @levelb) {
		# Note: @levela guaranteed to have same size as @levelb

		foreach my $a (@levela) {
			# a should always have children nodes, otherwise wouldn't be in level array
			
			foreach my $c (@{$a->{children}}) {

				# Record nodes at next level
				if($c->{children}) {
					push @nextlevela, $c;
				} else {
					$leafa{$c->{name}} = 1;
				}
			}
			
		}
		
		foreach my $b (@levelb) {
			# b should always have children nodes, otherwise wouldn't be in level array
			
			foreach my $c (@{$b->{children}}) {

				# Compare nodes at next level
				if($c->{children}) {
					push @nextlevelb, $c;
				} else {
					if($leafa{$c->{name}}) {
						$leafa{$c->{name}}++
					} else {
						# Leaf node not fount in A at this level
						return 1;
					}
				}
			}
			
		}
		
		if(scalar(@nextlevela) != scalar(@nextlevelb)) {
			# Different num of children
			return 1;
		}

		# Check if all leaf nodes in A also in B at this level
		foreach my $c (values %leafa) {
			return 1 unless $c == 2;
		}

		# Levels identical, move to next level
		@levela = @nextlevela;
		@nextlevela = ();
		%leafa = ();
		@levelb = @nextlevelb;
		@nextlevelb = ();
	}

	# Level order traversal complete
	# No isomorphisms detected
	return 0;
	
}


=head2 pruneNode

  Trim single node matching 'name' from tree
  
  Parameters:
  1) $node         => hash-ref to root node
  2) $remove_names => Reference to subroutine
       node names will be supplied as input. Names
       that return true will be removed.



=cut

sub pruneNode {
	my ($self, $node, $remove_names) = @_;
	
	if($node->{children}) {
		# Internal node
		
		# Find unpruned descendent nodes
		my @visableNodes;
		
		foreach my $childnode (@{$node->{children}}) {
			my ($visableNode) = $self->pruneNode($childnode, $remove_names);
			if($visableNode) {
				push @visableNodes, $visableNode;
			}
		}
		
		# Finished recursion
		# Transform internal node if needed
		
		if(@visableNodes > 1) {
			# Update children
			
			$node->{children} = \@visableNodes;
			
			return ($node); # record is empty unless $restrict_depth is true
			
		} elsif(@visableNodes == 1) {
			# No internal node needed, replace with singleton child node
			# Sum lengths
			my $replacementNode = shift @visableNodes;
			$replacementNode->{'length'} += $node->{'length'};
			return ($replacementNode);

		} else {
			# Empty node, remove
			return;
		}
		
	} else {
		# Leaf node
		
		my $genome_name = $node->{name};

		croak "Error: parameter 'remove_names' must be A code-ref." unless ref($remove_names) eq 'CODE';
		
		if($remove_names->($genome_name)) {
			# Remove node
			return;
		} else {
			
			return ($node);
		}
	}
}

=head2 coreNewickTrees

Download perl trees for the core pangenome
regions, convert to newick format and print
to file. Output is a two column tab-delim file:

pangenome_feature_id\dnewick_tree

=cut

sub coreNewickTrees {
	my $self = shift;
	my $outfile = shift;

	my $tree_rs = $self->dbixSchema->resultset('FeatureTree')->search(
		{
			'cvterm.name' => 'core_genome',
			'-not_bool' => 'feature_cvterms.is_not'
		},
		{
			prefetch => [qw/tree/],
			join => { feature => { feature_cvterms => 'cvterm'}}
		}
	);

	open(my $out, ">$outfile") or croak "Error: unable to write to file $outfile ($!).\n";
	my $taxa_only = 1;
	print $out join("\t", "pangenome_region_feature_id", "newick_tree")."\n";
	while(my $tree_row = $tree_rs->next) {
		my $newick = $self->perlToNewick($tree_row->tree->tree_string, $taxa_only);
		print $out join("\t", $tree_row->feature_id, $newick)."\n";
	}
	close $out;
}

=head2 perlToNewick

Print perl string representation of tree in Newick
format

=cut

sub perlToNewick {
	my $self = shift;
	my $perl_string = shift;
	my $taxa_names = shift; # If true, the gene/locus allele IDs will be stripped from names leaving just the genome ID.

	my $tree;
	unless(ref($perl_string) eq 'HASH') {
		# Convert string representation to hashref
		eval $perl_string;
		if($@) {
			croak "Error: invalid stringified perl structure ($!).";
		}
		croak "Error: stringified perl structure should populate the \$tree variable." unless $tree;
	}
	else {
		$tree = $perl_string;
	}

	my $newick_string = _newickRecursive($tree, $taxa_names);

	return $newick_string;
}

# Post-order print out of the newick tree
sub _newickRecursive {
	my $node = shift;
	my $taxa_names = shift;

	my $newick = '';

	my @required_fields = qw/name length/;
	croak "Error: Invalid perl tree node format. Missing required fields." if any { !defined($node->{$_}) } @required_fields;
	
	if($node->{children}) {
		# Internal node
		
		my @children_newick;
		foreach my $c (@{$node->{children}}) {
			push @children_newick, _newickRecursive($c, $taxa_names);
		}
		$newick = '('.join(',',@children_newick).')'.':'.$node->{length};
	}
	else {
		# Leaf node
		my $n;
		if($taxa_names) {
			$n = _strip_allele_id($node->{name});
		}
		else {
			$n = $node->{name};
		}
		$newick = join('',$n,':',$node->{length}); 
	}

	return $newick

}

sub _strip_allele_id {
	my $n = shift;

	$n =~ s/^(public_\d+|private_\d+).*/$1/;

	return $n
}


1;
