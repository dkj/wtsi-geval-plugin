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

# This code will be placed at risk.  At the moment, it doesn't seem to be used
# wc2 2016

package EnsEMBL::Web::Component::Location::MultiBottom;

use strict;

use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object;
  
  return if $hub->param('show_bottom_panel') eq 'no';
  
  my $threshold = 1000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE || 1);
  
  return $self->_warning('Region too large', '<p>The region selected is too large to display in this view - use the navigation above to zoom in...</p>') if $object->length > $threshold;
  
  my $image_width     = $self->image_width;
  my $primary_slice   = $object->slice;
  my $primary_species = $hub->species;
  my $primary_strand  = $primary_slice->strand;
  my $slices          = $object->multi_locations;
  my $seq_region_name = $object->seq_region_name;
  my $short_name      = $slices->[0]->{'short_name'};
  my $max             = scalar @$slices;
  my $base_url        = $hub->url($hub->multi_params);
  my $s               = $hub->get_viewconfig('MultiTop')->get('show_top_panel') eq 'yes' ? 3 : 2;
  my $gene_join_types = EnsEMBL::Web::Constants::GENE_JOIN_TYPES;
  my $methods         = { BLASTZ_NET => $hub->param('opt_pairwise_blastz'), TRANSLATED_BLAT_NET => $hub->param('opt_pairwise_tblat'), LASTZ_PATCH => $hub->param('opt_pairwise_lpatch') };
  my $join_alignments = grep $_ ne 'off', values %$methods;
  my $join_genes      = $hub->param('opt_join_genes_bottom') eq 'on';

  my $compara_db      = $join_genes ? new EnsEMBL::Web::DBSQL::DBConnection($primary_species)->_get_compara_database : undef;
  my $i               = 1;
  my $primary_image_config;
  my @images;
  
  $methods->{'LASTZ_NET'} = $methods->{'BLASTZ_NET'};
  
  foreach (@$slices) {
    my $image_config   = $hub->get_imageconfig('MultiBottom', "contigview_bottom_$i", $_->{'species'});
    my $highlight_gene = $hub->param('g' . ($i - 1));
    
    $image_config->set_parameters({
      container_width => $_->{'slice'}->length,
      image_width     => $image_width,
      slice_number    => "$i|$s",
      multi           => 1,
      compara         => $i == 1 ? 'primary' : $_->{'species'} eq $primary_species ? 'paralogue' : 'secondary',
      base_url        => $base_url,
      join_types      => $gene_join_types
    });
    
    $image_config->get_node('scalebar')->set('caption', $_->{'short_name'});
    
    $_->{'slice'}->adaptor->db->set_adaptor('compara', $compara_db) if $compara_db;
    
    if ($i == 1) {
      $image_config->multi($methods, $seq_region_name, $i, $max, $slices->[$i]) if $join_alignments && $max == 2 && $slices->[$i]{'species_check'} ne $primary_species;
      $image_config->join_genes($i, $max, $slices->[$i]) if $join_genes && $max == 2;
      
      push @images, $primary_slice, $image_config if $max < 3;
      
      $primary_image_config = $image_config;
    } else {
	


      $image_config->multi($methods, $_->{'target'} || $seq_region_name, $i, $max, $slices->[0]) if $join_alignments && $_->{'species_check'} ne $primary_species;
      $image_config->join_genes($i, $max, $slices->[0]) if $join_genes;
      $image_config->highlight($highlight_gene) if $highlight_gene;
      
      push @images, $_->{'slice'}, $image_config;
      
      if ($max > 2 && $i < $max) {
        # Make new versions of the primary image config because the alignments required will be different each time
        if ($join_alignments || $join_genes) {
          $primary_image_config = $hub->get_imageconfig('MultiBottom', "contigview_bottom_1_$i", $primary_species);
          
          $primary_image_config->set_parameters({
            container_width => $primary_slice->length,
            image_width     => $image_width,
            slice_number    => "1|$s",
            multi           => 1,
            compara         => 'primary',
            base_url        => $base_url,
            join_types      => $gene_join_types
          });
        }
        
        if ($join_alignments) {
          $primary_image_config->get_node('scalebar')->set('caption', $short_name);
          $primary_image_config->multi($methods, $seq_region_name, 1, $max, map $slices->[$_], $i - 1, $i);
        }
        
        $primary_image_config->join_genes(1, $max, map $slices->[$_], $i - 1, $i) if $join_genes;
        
        push @images, $primary_slice, $primary_image_config;
      }
    }
    
    $i++;
  }
  
  if ($hub->param('export')) {
    $_->set_parameter('export', 1) for grep $_->isa('EnsEMBL::Web::ImageConfig'), @images;
  }
  
  my $image = $self->new_image(\@images);
  
  return if $self->_export_image($image);
  
  $image->imagemap = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  $image->{'panel_number'} = 'bottom';
  
  my $html = $image->render;
  
  $html .= $self->_info(
    'Configuring the display',
    '<p>To change the tracks you are displaying, use the "<strong>Configure this page</strong>" button on the left.</p>
     <p>To add or remove species, click the "<strong>Select species</strong>" button.</p>'
  );
  
  return $html;
}

1;
