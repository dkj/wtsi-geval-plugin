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

package EnsEMBL::Web::Component::Location::ViewBottom;

use strict;
use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->configurable(1);
  $self->has_image(1);
}

sub _add_object_track {
  my $self = shift;

  my $extra = '';
  my $hub = $self->hub;
  my $image_config = $hub->get_imageconfig('contigviewbottom');
  # Add track for gene if not on by default
  if (my $gene = $hub->core_objects->{'gene'}) {
    my $key  = $image_config->get_track_key('transcript', $gene);
    my $node = $image_config->get_node(lc $key);
 
    if($node) {
      my $current = $node->get('display');
      my $default = $node->data->{'display'};
      if($current eq 'off' and $default eq 'off') {
        my $flag = $hub->session->get_data(type => 'auto_add', code => lc $key);
        unless($flag->{'data'}) {             # haven't done this before
          $image_config->update_track_renderer(lc $key,'transcript_label');
          $extra .= $self->_info("Information","<p>The track containing the highlighted gene has been added to your display.</p>")."<br/>";
          $hub->session->set_data(type => 'auto_add' , code => lc $key, data => 1); 
          $hub->session->store();
        }
      }
    }
  }
  return $extra;
}

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;

  # wc2 Request from analysts to view 2MB length  
  my $threshold   = 2000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE || 1);
  my $image_width = $self->image_width;
  my $info = '';
  
  return $self->_warning('Region too large', '<p>The region selected is too large to display in this view - use the navigation above to zoom in...</p>') if $object->length > $threshold;
  
  my $slice        = $object->slice;
  my $length       = $slice->end - $slice->start + 1;
  my $image_config = $hub->get_imageconfig('contigviewbottom');
  my $s            = $hub->get_viewconfig('ViewTop')->get('show_panel') eq 'yes' ? 3 : 2;
  
  $image_config->set_parameters({
    container_width => $length,
    image_width     => $image_width || 800, # hack at the moment
    slice_number    => "1|$s"
  });

  ## Force display of individual low-weight markers on pages linked to from Location/Marker
  if (my $marker_id = $hub->param('m')) {
    $image_config->modify_configs(
      [ 'marker' ],
      { marker_id => $marker_id }
    );
  }

  $info .= $self->_add_object_track();

  # Add multicell configuration
  if (keys %{$hub->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'}{'cell_type'}{'ids'}}){
    my $web_slice_obj = $self->new_object( 'Slice', $slice, $object->__data );
    my $cell_line_data = $web_slice_obj->get_cell_line_data($image_config);
    $image_config->{'data_by_cell_line'} = $cell_line_data;
  } 

  $image_config->_update_missing($object);
  
  my $image = $self->new_image($slice, $image_config, $object->highlights);
  
	return if $self->_export_image($image);
  
  $image->{'panel_number'} = 'bottom';
  $image->imagemap         = 'yes';
  $image->set_button('drag', 'title' => 'Click or drag to centre display');
  
  return $info.$image->render;
}


1;
