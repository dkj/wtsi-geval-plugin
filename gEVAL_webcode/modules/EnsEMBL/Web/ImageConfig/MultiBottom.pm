#-------------------------------------------------------------------------------#
# Copyright (c) 2014 by Genome Research Limited
#  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#    * Neither the name of the Wellcome Trust Sanger Institute, Genome
#      Research Limited, Genome Reference Consortium nor the
#      names of its contributors may be used to endorse or promote products
#      derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL GENOME RESEARCH LIMITIED BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#-------------------------------------------------------------------------------#

package EnsEMBL::Web::ImageConfig::MultiBottom;
use strict;
use base qw(EnsEMBL::Web::ImageConfig::MultiSpecies);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    sortable_tracks => 1,  # allow the user to reorder tracks
    opt_lines       => 1,  # register lines
    spritelib       => { default => $self->species_defs->ENSEMBL_SERVERROOT . '/htdocs/img/sprites' }
  });

  # Add menus in the order you want them for this display
  $self->create_menus(qw(
    sequence
    marker
    transcript
    prediction

    gEVAL_other
    gEVAL_all
    gEVAL_ends
    gEVAL_digest
    gEVAL_mf_clone
    gEVAL_daf_aln
    optical_map  

    dna_align_cdna
    dna_align_est 
    dna_align_rna 
    dna_align_other 
    protein_align
    rnaseq
    simple
    misc_feature	
    variation 
    somatic 
    functional
    oligo
    repeat
    user_data
    decorations 
    information 
  ));
  
  # Add in additional tracks
  $self->load_tracks;
  $self->load_configured_das;
 
  ##======= add gEVAL generic tracks =======##
  $self->add_pgp_track(  'sequence',  'fpc_contig', 'FPC contig',  'gEVAL_fpc',   { 'display' => 'off', 'strand' => 'f', 'description' => 'FPC Contigs on assembly path'}, 'sequence');
  $self->add_pgp_track(  'sequence',  'scaffold',  'Scaffolds',   'gEVAL_scaf',  { 'display' => 'off', 'strand' => 'f', 'description' => 'Scaffolds on assembly path'}, 'sequence');
  $self->add_gEVAL_cloneend_tracks('gEVAL_ends', 'gEVAL_ends_link', 'norep');
  $self->add_gEVAL_mf_clone('gEVAL_mf_clone');
  $self->add_gEVAL_markers('marker');
  $self->add_gEVAL_other('gEVAL_daf_aln');

  $self->add_tracks('sequence', 
    [ 'contig', 'Contigs', 'gEVAL_contig', { display => 'normal', strand => 'r', description => 'Track showing underlying assembly contigs' }]
  );

  $self->add_tracks('decorations',
    [ 'scalebar',  '', 'scalebar',   { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',     '', 'ruler',      { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '', 'draggable',  { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'nav',       '', 'navigation', { display => 'normal', strand => 'b', menu => 'no' }]
  );
  
  $_->set('display', 'off') for grep $_->id =~ /^chr_band_/, $self->get_node('decorations')->nodes; # Turn off chromosome bands by default
}

sub multi {
  my ($self, $methods, $chr, $pos, $total, @slices) = @_;
  my $sp              = $self->{'species'};
  my $multi_hash      = $self->species_defs->multi_hash;
  my $primary_species = $self->hub->species;
  my $p               = $pos == $total && $total > 2 ? 2 : 1;
  my ($i, %alignments, @strands);
  
  foreach my $db (@{$self->species_defs->compara_like_databases || []}) {
    next unless exists $multi_hash->{$db};
    
    foreach (values %{$multi_hash->{$db}{'ALIGNMENTS'}}, @{$multi_hash->{$db}{'INTRA_SPECIES_ALIGNMENTS'}{'REGION_SUMMARY'}{$sp}{$chr} || []}) {
      next unless $methods->{$_->{'type'}};
      next unless $_->{'class'} =~ /pairwise_alignment/;
      next unless $_->{'species'}{$sp} || $_->{'species'}{"$sp--$chr"};
      
      my %align = %$_; # Make a copy for modification
      
      $i = $p;
      
      foreach (@slices) {
        if ($align{'species'}{$_->{'species'} eq $sp ? $_->{'species_check'} : $_->{'species'}} && !($_->{'species_check'} eq $primary_species && $sp eq $primary_species)) {
          $align{'order'} = $i;
          $align{'ori'}   = $_->{'strand'};
          $align{'gene'}  = $_->{'g'};
          last;
        }
        
        $i++;
      }
      
      next unless $align{'order'};
      
      $align{'db'} = lc substr $db, 9;
      
      push @{$alignments{$align{'order'}}}, \%align;
      
      $self->set_parameter('homologue', $align{'homologue'});
    }
  }
  
  if ($pos == 1) {
    @strands = $total == 2 ? qw(r) : scalar keys %alignments == 2 ? qw(f r) : [keys %alignments]->[0] == 1 ? qw(f) : qw(r); # Primary species
  } elsif ($pos == $total) {
    @strands = qw(f);   # Last species - show alignments on forward strand.
  } elsif ($pos == 2) {
    @strands = qw(r);   # First species where $total > 2
  } else {
    @strands = qw(r f); # Secondary species in the middle of the image
  }
  
  # Double up for non primary species in the middle of the image
  $alignments{2} = $alignments{1} if $pos != 1 && scalar @strands == 2 && scalar keys %alignments == 1;
  
  my $decorations = $self->get_node('decorations');
  
  foreach (sort keys %alignments) {
    my $strand = shift @strands;
    
    foreach my $align (sort { $a->{'type'} cmp $b->{'type'} } @{$alignments{$_}}) {
      my ($other_species) = grep $_ ne $sp, keys %{$align->{'species'}};
      
      $decorations->before(
        $self->create_track("$align->{'id'}:$align->{'type'}:$_", $align->{'name'}, {
          glyphset                   => '_alignment_pairwise',
          colourset                  => 'pairwise',
          name                       => $align->{'name'},
          species                    => [split '--', $other_species]->[0],
          strand                     => $strand,
          display                    => $methods->{$align->{'type'}},
          db                         => $align->{'db'},
          type                       => $align->{'type'},
          ori                        => $align->{'ori'},
          method_link_species_set_id => $align->{'id'},
          target                     => $align->{'target_name'},
          join                       => 1,
          menu                       => 'no'
        })
      );
    }
  }
}

sub join_genes {
  my $self = shift;
  my ($pos, $total, @slices) = @_;
  
  my ($prev_species, $prev_target, $next_species, $next_target) = map { $_->{'species'}, $_->{'target'} } @slices;
  
  if (($pos == 1 && $total == 2) || ($pos == 2 && $total > 2)) {
     ($prev_species, $next_species) = ('', $prev_species);
     ($prev_target,  $next_target)  = ('', $prev_target);
  }
  
  if ($pos > 2 && $pos < $total && $total > 3) {
    $next_species = $prev_species;
    $next_target  = $prev_target;
  }
  
  foreach ($self->get_node('transcript')->nodes) {
    $_->set('previous_species', $prev_species) if $prev_species;
    $_->set('next_species',     $next_species) if $next_species;
    $_->set('previous_target',  $prev_target)  if $prev_target;
    $_->set('next_target',      $next_target)  if $next_target;
    $_->set('join', 1);
  }
}

sub highlight {
  my ($self, $gene) = @_;
  $_->set('g', $gene) for $self->get_node('transcript')->nodes; 
}

1;
