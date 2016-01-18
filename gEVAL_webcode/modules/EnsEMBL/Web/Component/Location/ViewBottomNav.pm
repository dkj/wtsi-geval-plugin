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

package EnsEMBL::Web::Component::Location::ViewBottomNav;

use strict;
use HTML::Entities qw(encode_entities);
use base qw(EnsEMBL::Web::Component::Location);

sub _init {
  my $self = shift;
  $self->ajaxable(1);  # Must be ajaxable for slider/button nav stuff to work properly.
  $self->has_image(2); # Cache key and tags depend on image width, so lie about having images so that they are correct. Setting has_image to something other than 1 stops the image_panel class being added
}

sub set_cache_key {
  my $self = shift;
  $self->SUPER::set_cache_key;
  $ENV{'CACHE_KEY'} .= ':JSON' if $self->hub->param('update_panel');
}

sub content_region {
  return $_[0]->content([ [4,1e4], [6,5e4], [8,1e5], [10,5e5], [12,1e6], [14,2e6], [16,5e6], [18,1e7] ], 'region')
}

sub content {
  my $self             = shift;
  my $ramp_entries     = shift || [ [4,1e3], [6,5e3], [8,1e4], [10,5e4], [12,1e5], [14,2e5], [16,5e5], [18,1e6] ];
  my $hub              = $self->hub;
  my $object           = $self->object;
  my $image_width      = $self->image_width . 'px';
  my $seq_region_start = $object->seq_region_start;
  my $seq_region_end   = $object->seq_region_end;
  my $cp               = int(($seq_region_end + $seq_region_start) / 2);
  my $wd               = $seq_region_end - $seq_region_start + 1;
  my $r                = $hub->param('r');
  
  $self->{'update'} = $hub->param('update_panel');
  
  my $values = [
    $self->ajax_url(shift, { __clear => 1, r => $r }),
    $r,
    $self->nav_url($seq_region_start - 2*$wd, $seq_region_end - 2*$wd),
    $self->nav_url($seq_region_start - $wd, $seq_region_end - $wd),
    $self->nav_url($cp - int($wd/4) + 1, $cp + int($wd/4)),
    $self->nav_url($cp - $wd + 1, $cp + $wd),
    $self->nav_url($seq_region_start + $wd, $seq_region_end + $wd),
    $self->nav_url($seq_region_start + 2*$wd, $seq_region_end + 2*$wd),

    $self->nav_url($cp - 1e6 + 1, $cp + 1e6 )   # wc2 This is for the 2MB window stored and used in the sprintf below.
  ];
  
  my $ramp = $self->ramp($ramp_entries, $wd, $cp);
  
  if ($self->{'update'}) {
    my $i = 0;
    my @ramp_values;
    
    foreach (@$ramp) {
      push @ramp_values, $_->[1];
      unshift @$values, $i if $_->[3];
      $i++;
    }
    
    splice @$values, 6, 0, @ramp_values;
    
    return $self->jsonify($values);
  }

  return $self->navbar($ramp, $wd, $values);
}

sub navbar {
  my ($self, $ramp, $wd, $values) = @_;
  
  my $hub          = $self->hub;
  my $img_url      = $self->img_url;
  my $image_width  = $self->image_width . 'px';
  my $url          = $hub->url({ %{$hub->multi_params(0)}, function => undef, r => undef, g => undef }, 1);

  #
  # ::CHANGE:: wc2 changed the secondary search form to specifically look for clones/sequence (most common) and genome alignments
  #
  my $url2         = $hub->url({ "action"=>"Genome", id=>undef, ftype=>undef}, 1);
  # ::

  my $psychic      = $hub->url({ type => 'psychic', action => 'Location', __clear => 1 });
  my $extra_inputs = join '', map { sprintf '<input type="hidden" name="%s" value="%s" />', encode_entities($_), encode_entities($url->[1]{$_}) } keys %{$url->[1] || {}};
  my $g            = $hub->param('g');
  my $g_input      = $g ? qq{<input name="g" value="$g" type="hidden" />} : '';
  
  # wc2 - Updated to add seqid search window, and 2mb button [requires overide of css class image_nav] 
  return sprintf (qq{
      <div class="navbar print_hide" style="width:$image_width">
        <input type="hidden" class="panel_type" value="LocationNav" />
        <input type="hidden" class="update_url" value="%s" />
        <div class="relocate">
          <form action="$url->[0]" method="get">
            <label for="loc_r">Location:</label>
            $extra_inputs
            $g_input
            <input name="r" id="loc_r" class="location_selector" value="%s" type="text" />
            <a class="go-button" href="">Go</a>
          </form>
          <div class="js_panel" style="float: left; margin: 0">
            <input type="hidden" class="panel_type" value="AutoComplete" />
            <form action="$url->[0]" method="get" class="autocomplete">
              <label for="loc_q">SeqID:</label>
              $extra_inputs
              <input name="g" value="" type="hidden" />
              <input name="region" id="loc_reg" class="autocomplete"  value="" type="text" />
              <a class="go-button" href="">Go</a>
            </form>
          </div>

        </div>
        <div class="image_nav" style="width:346px">
          <a href="%s" class="move left_2" title="Back 2 windows"></a>
          <a href="%s" class="move left_1" title="Back 1 window"></a>
          <a href="%s" class="zoom_in" title="Zoom in"></a>
          <span class="ramp">$ramp</span>
          <span class="slider_wrapper">
            <span class="slider_left"></span>
            <span class="slider"><span class="slider_label floating_popup">$wd</span></span>
            <span class="slider_right"></span>
          </span>
          <a href="%s" class="zoom_out" title="Zoom out"></a>
          <a href="%s" class="move right_1" title="Forward 1 window"></a>
          <a href="%s" class="move right_2" title="Forward 2 windows"></a>
          <a href="%s" class="go-button" title="2MB Window (warning: can overload with data)">2MB</a>
        </div>
        <div class="invisible"></div>
      </div>},
    @$values
  );
}

sub ramp {
  my ($self, $ramp_entries, $wd, @url_params) = @_;
  
  my $scale = $self->hub->species_defs->ENSEMBL_GENOME_SIZE || 1;
  my $x     = 0;
  my (@ramp, @mp);
  
  foreach (@$ramp_entries) {
    $_->[1] *= $scale;
    push @mp, sqrt($x * $_->[1]);
    $x = $_->[1];
  }
  
  push @mp, 1e30;
  
  my $l = shift @mp;
  
  my $img_url = $self->img_url;
  
  foreach (@$ramp_entries) {
    my $r = shift @mp; 
    
    push @ramp, [
      '<a href="%s" name="%d" class="ramp%s" title="%d bp" style="height:%dpx"></a>',
      $self->ramp_url($_->[1], @url_params),
      $_->[1], 
      $wd > $l && $wd <= $r ? ' selected' : '',
      $_->[1],
      $_->[0]
    ];
    
    $l = $r;
  }
  
  return $self->{'update'} ? \@ramp : join '', map { sprintf shift @$_, @$_ } @ramp;
}

sub ramp_url {
  my ($self, $entry, $cp) = @_;
  return $self->nav_url($cp - ($entry/2) + 1, $cp + $entry/2);
}

sub nav_url {
  my ($self, $s, $e) = @_;
  my $hub    = $self->hub;
  my $object = $self->object;
  my $max    = $object->seq_region_length;
  
  ($s, $e) = (1, $e - $s || 1) if $s < 1;
  ($s, $e) = ($max - ($e - $s), $max) if $e > $max;
  
  $s = $e if $s > $e;
  
  return $object->seq_region_name . ":$s-$e" if $self->{'update'};
  
  return $hub->url({ 
    %{$hub->multi_params(0)},
    r        => $object->seq_region_name . ":$s-$e",
    function => undef
  });
}

1;
