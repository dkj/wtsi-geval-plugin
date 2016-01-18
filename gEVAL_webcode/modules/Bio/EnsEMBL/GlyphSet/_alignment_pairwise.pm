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

package Bio::EnsEMBL::GlyphSet::_alignment_pairwise;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

sub render_normal {
  my $self = shift;
  
  return $self->render_text if $self->{'text_export'};
  
  my $width       = 1e5;
  my $container   = $self->{'container'};
  my $strand      = $self->strand;
  my $strand_flag = $self->my_config('strand');
  
  return if $strand_flag eq 'r' && $strand != -1;
  return if $strand_flag eq 'f' && $strand !=  1;
  
  my $self_species   = $container->{'web_species'};
  my $length         = $container->length;
  my $chr            = $container->seq_region_name;
  my $pix_per_bp     = $self->scalex;
  my $draw_cigar     = $pix_per_bp > 0.2;
  my $feature_key    = lc $self->my_config('type');
  my $other_species  = $self->my_config('species');
  my $other_ori      = $self->my_config('ori');
  my $depth          = $self->depth || 6;
  my $feature_colour = $self->my_colour($feature_key);
  my $join_col       = "green4", #  wc2 change.  OLD: $self->my_colour($feature_key, 'join')   || 'gold'; 
  my $join_z         = $self->my_colour($feature_key, 'join_z') || 100;
  my $h              = $self->get_parameter('opt_halfheight') ? 4 : 8;
  my $link           = $self->get_parameter('compara') ? $self->my_config('join') : 0;
  my $mlss_id        = $self->my_config( 'method_link_species_set_id' );
  my $c              = 0; # Diagnostic counter
  my $k              = 0; # Diagnostic counter
  my %ids;

  $self->_init_bump(undef, $depth); # initialize bumping

  foreach my $f (@{$self->features||[]}) {
    next if $strand_flag eq 'b' && $strand != $f->hstrand || $f->end < 1 || $f->start > $length;
    my $key = $f->hseqname . ':' . ($f->group_id || ('00' . $k++));

    $ids{$key}{start} = $f->start if (!$ids{$key} or $f->start < $ids{$key}{start});
    $ids{$key}{end} = $f->end if (!$ids{$key} or $f->end > $ids{$key}{end});
    push @{$ids{$key}{features}}, [$f->start, $f];
  }

  # sort alignment groups by size
  my @sorted_group_ids = sort { ($ids{$b}{end} - $ids{$b}{start}) <=> ($ids{$a}{end} - $ids{$a}{start}) || $a cmp $b } keys %ids;

  foreach my $i (@sorted_group_ids) {
    my ($seqregion) = split /:/, $i;

    # Get the features for this net and sort them by start
    my @features   = sort { $a->[0] <=> $b->[0] } @{$ids{$i}{features}};
    my $hs_net     = $features[0][1]->hstart; # start on the other species
    my $he_net     = $features[0][1]->hend; # end on the other species
    my $bump_start = (($features[0][0] < 1 ? 1 : $features[0][0]) * $pix_per_bp) - 1; # start in pixels
    my $bump_end   = ($features[-1][1]->end > $length ? $length : $features[-1][1]->end) * $pix_per_bp; # end in pixels
    my $row        = $self->bump_row(int $bump_start, int $bump_end);

    next if $row > $depth;

    #######################################################
    ## Get the big box for the net:
    my $y_pos = -$row * int(1.5 * $h) * $strand;
    my $x = -1000000;
    my $width = $features[-1][1]->end;
    if ($width > $length) {
      $width = $length;
    }
    if ($features[0][1]->start > 0) {
      $width -= $features[0][1]->start - 1;
    }

    my $n0 = $features[0][1]->seq_region_name . ":" .
        $features[0][1]->seq_region_start . "-" . $features[-1][1]->seq_region_end;

    my $net_composite = $self->Composite({
      x     => $features[0][0] > 1 ? $features[0][0] - 1 : 0,
      y     => $y_pos,
      width => $width,
      height => $h,
      bordercolour => $feature_colour,
    });
    
    my $url_species = ucfirst $features[0][1]->species; # FIXME: ucfirst hack for compara species names
    my ($rs, $re) = $self->slice2sr($features[0][1]->start, $features[-1][1]->end);
    
    #######################################################

    my @internal_boxes;
    
    foreach (@features) {
      my $f = $_->[1];
      
      ## Make sure we have the right start and end of the nets on the other species
      $hs_net = $f->hstart if $f->hstart < $hs_net;
      $he_net = $f->hend   if $f->hend   > $he_net;

      next if int($f->end * $pix_per_bp) <= int($x * $pix_per_bp);

      $c++;

      if ($draw_cigar) {
        $self->draw_cigar_feature({
          composite      => $net_composite,
          feature        => $f,
          height         => $h,
          y         => $y_pos,
          feature_colour => $feature_colour,
          delete_colour  => 'black',
          scalex         => $pix_per_bp,
          do_not_flip    => 1,
          link           => $link,
          join_col       => $join_col,
          join_z         => $join_z,
          other_ori      => $other_ori
        });
      } else {
        my $s = $_->[0] < 1 ? 1 : $_->[0];
        my $e = $f->end > $length ? $length : $f->end;

        $x = $e;

        my $r = "$chr:". $f->seq_region_start . "-" . $f->seq_region_end;
        my $r1 = $f->hseqname . ':' . $f->hstart . '-' . $f->hend;
        my $ori = $f->hstrand * $f->strand > 0 ? 'Forward' : 'Reverse';
        my $box = $self->Rect({
          x         => $s - 1,
          y         => $y_pos,
          width     => $e - $s + 1,
          height    => $h,
          colour    => $feature_colour,
          absolutey => 1,
        });

        push @internal_boxes, [ $box, $r, $r1, $ori ];

        if ($link) {
          my $slice_start = $f->slice->start;
          my $slice_end   = $f->slice->end;
          my $fstrand     = $f->strand;
          my $hstrand     = $f->hstrand;
          my $s1          = $fstrand == 1 ? $slice_start + $f->start - 1 : $slice_end - $f->end   + 1;
          my $e1          = $fstrand == 1 ? $slice_start + $f->end   - 1 : $slice_end - $f->start + 1;
          my $tag1        = join ':', $f->species, $f->slice->seq_region_name, $s1, $e1;
          my $tag2        = join ':', $f->hspecies, $f->hseqname, $f->hstart, $f->hend;
          my $tag         = $strand == 1 ? "$tag1#$tag2" : "$tag2#$tag1";
          my $x;
          
          if ($other_ori == $hstrand && $other_ori == 1) {
            $x = $strand == -1 ? 0 : 1; # Use the opposite value to normal to ensure alignments which are between different orientations by default do not display a cross-over join
          } else {
            $x = $strand == -1 ? 1 : 0;
          }
          
          $x ||= 1 if $fstrand == 1 && $hstrand * $other_ori == -1; # the feature has been flipped, so force x to the same value each time to achieve a cross-over join
          
          $self->join_tag($box, $tag, {
            x     => $x,
            y     => $strand == -1 ? 1 : 0,
            z     => $join_z,
            col   => $join_col,
            #style => 'fill'  # wc2
          });
          
          $self->join_tag($box, $tag, {
            x     => !$x,
            y     => $strand == -1 ? 1 : 0,
            z     => $join_z,
            col   => $join_col,
            #style => 'fill'  # wc2
          });
        }
        
      }
    }
    
    my $n1 = $features[0][1]->hseqname . ":$hs_net-$he_net";
    
    foreach (@internal_boxes) {
      my ($box, $r, $r1, $ori) = @$_;
      
      $box->href($self->_url({
        type    => 'Location',
        action  => 'PairwiseAlignment',
        species => $url_species,
        r       => $r,
        r1      => $r1,
        n0      => $n0,
        n1      => $n1,
        s1      => $other_species,
        method  => $self->my_config('type'),
        align   => $mlss_id,
        orient  => $ori,
      }));
      
      $self->push($box);
    }
    
    $net_composite->href($self->_url({
      type    => 'Location',
      action  => 'PairwiseAlignment',
      species => $url_species,
      r       => undef,
      n0      => $n0,
      n1      => $n1,
      s1      => $other_species,
      method  => $self->my_config('type'),
      align   => $mlss_id,
      orient  => $features[0][1]->hstrand * $features[0][1]->strand > 0 ? 'Forward' : 'Reverse'
    }));
    
    $self->push($net_composite);
  }
  
  # No features show "empty track line" if option set
  $self->errorTrack(sprintf 'No %s features in this region', $self->my_config('name')) unless $c || $self->{'config'}->get_option('opt_empty_tracks') == 0;
  $self->timer_push('Features drawn');
}

sub render_compact {
  my $self = shift;
  
  return $self->render_text if $self->{'text_export'};
  
  my $width          = 1e5;
  my $container      = $self->{'container'};
  my $strand         = $self->strand;
  my $strand_flag    = $self->my_config('strand');
  
  return if $strand_flag eq 'r' && $strand != -1;
  return if $strand_flag eq 'f' && $strand !=  1;
  
  my $self_species   = $container->{'web_species'};
  my $length         = $container->length;
  my $chr            = $container->seq_region_name;
  my $pix_per_bp     = $self->scalex;
  my $draw_cigar     = $pix_per_bp > 0.2;
  my $feature_key    = lc $self->my_config('type');
  my $other_species  = $self->my_config('species');
  my $other_ori      = $self->my_config('ori');
  my $depth          = $self->depth;
  my $feature_colour = $self->my_colour($feature_key);
  my $join_col       = $self->my_colour($feature_key, 'join')   || 'gold'; 
  my $join_z         = $self->my_colour($feature_key, 'join_z') || 100;
  my $h              = $self->get_parameter('opt_halfheight') ? 4 : 8;
  my $link           = $self->get_parameter('compara') ? $self->my_config('join') : 0;
  my $mlss_id        = $self->my_config( 'method_link_species_set_id' );
  my $c              = 0;
  my $x              = -1e8;

  $self->_init_bump(undef, $depth);  # initialize bumping 
  
  my @features = sort { $a->[0] <=> $b->[0] }
    map  { [ $_->start, $_ ] }
    grep { !(($strand_flag eq 'b' && $strand != $_->hstrand) || ($_->start > $length) || ($_->end < 1)) } 
    @{$self->features||[]};
  
  foreach (@features) {
    my ($start, $f) = @$_;
    my $end = $f->end;
    
    ($start, $end) = ($end, $start) if $end < $start; # Flip start end
    
    my ($rs, $re) = $self->slice2sr($start, $end);
    
    $start = 1 if $start < 1;
    $end   = $length if $end > $length;
    
    next if int($end * $pix_per_bp) == int($x * $pix_per_bp);
    
    $x = $start;
    $c++;
    
    my $composite;
    
    # zmenu links depend on whether jumping within or between species;
    my $zmenu = {
      type    => 'Location',
      action  => 'PairwiseAlignment',
      species => ucfirst $f->species, # FIXME: ucfirst hack for compara species names
      r       => "$chr:$rs-$re",
      r1      => $f->hseqname . ':' . $f->hstart . '-' . $f->hend,
      s1      => $other_species,
      method  => $self->my_config('type'),
      align   => $mlss_id,
      orient  => $f->hstrand * $f->strand > 0 ? 'Forward' : 'Reverse'
    };
    
    if ($draw_cigar) {
      $composite = $self->Composite({
        href  => $self->_url($zmenu),
        x     => $start - 1,
        width => 0,
        y     => 0
      });
      
      $self->draw_cigar_feature({
        composite      => $composite, 
        feature        => $f, 
        height         => $h, 
        feature_colour => $feature_colour, 
        delete_colour  => 'black', 
        scalex         => $pix_per_bp, 
        do_not_flip    => 1,
        link           => $link,
        join_col       => $join_col,
        join_z         => $join_z,
        other_ori      => $other_ori
      });
      
      $composite->bordercolour($feature_colour);
    } else {

    	# wc2 ::
	# Colour differentiation for the zfish WGS
	# colours keep with tradition
	my $rect_colour = $feature_colour;
	my $target_type = $self->my_config('species');
	my $self_type   = $f->species;
	#warn "$self_type is ".$f->species."\n";
	$rect_colour = "purple"   if ($self_type =~ /wgs28/i || $target_type =~ /wgs28/i);
	$rect_colour = "7D1B7E"   if ($self_type =~ /wgs29/i || $target_type =~ /wgs29/i);
	$rect_colour = "purple4"  if ($self_type =~ /wgs31/i || $target_type =~ /wgs31/i);


      $composite = $self->Rect({
        x         => $start - 1,
        y         => 0,
        width     => $end - $start + 1,
        height    => $h,
        colour    => $rect_colour, #$feature_colour,
        absolutey => 1,
        _feature  => $f, 
        href      => $self->_url($zmenu)
      });
      
      if ($link) {
        my $slice_start = $f->slice->start;
        my $slice_end   = $f->slice->end;
        my $fstrand     = $f->strand;
        my $hstrand     = $f->hstrand;
        my $s1          = $fstrand == 1 ? $slice_start + $f->start - 1 : $slice_end - $f->end   + 1;
        my $e1          = $fstrand == 1 ? $slice_start + $f->end   - 1 : $slice_end - $f->start + 1;
        my $tag1        = join ':', $f->species, $f->slice->seq_region_name, $s1, $e1;
        my $tag2        = join ':', $f->hspecies, $f->hseqname, $f->hstart, $f->hend;
        my $tag         = $strand == 1 ? "$tag1#$tag2" : "$tag2#$tag1";
        my $x;
        
        if ($other_ori == $hstrand && $other_ori == 1) {
          $x = $strand == -1 ? 0 : 1; # Use the opposite value to normal to ensure alignments which are between different orientations by default do not display a cross-over join
        } else {
          $x = $strand == -1 ? 1 : 0;
        }
        
        $x ||= 1 if $fstrand == 1 && $hstrand * $other_ori == -1; # the feature has been flipped, so force x to the same value each time to achieve a cross-over join
        
        $self->join_tag($composite, $tag, {
          x     => $x,
          y     => $strand == -1 ? 1 : 0,
          z     => $join_z,
          col   => $join_col,
          style => 'fill'
        });
        
        $self->join_tag($composite, $tag, {
          x     => !$x,
          y     => $strand == -1 ? 1 : 0,
          z     => $join_z,
          col   => $join_col,
          style => 'fill'
        });
      }
    }
    
    $self->push($composite);
  }
  
  # No features show "empty track line" if option set
  $self->errorTrack(sprintf 'No %s features in this region', $self->my_config('name')) unless $c || $self->{'config'}->get_option('opt_empty_tracks') == 0;
}

sub genomic_align_blocks {
  my $self = shift;
  
  my $compara_dba = $self->dbadaptor('multi', $self->my_config('db'));

  my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;
  my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID(
      $self->my_config('method_link_species_set_id'));
  my $genomic_align_block_adaptor = $compara_dba->get_GenomicAlignBlockAdaptor;
  my $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
      $method_link_species_set, $self->{'container'});

  my $target = $self->my_config('target');
  if ($target) {
    $genomic_align_blocks = [
        grep { $_->get_all_non_reference_genomic_aligns->[0]->dnafrag->name eq $target } @{$genomic_align_blocks || []}];
  }

  return $genomic_align_blocks;
}

sub features {
  my $self = shift;
  
  my $features = $self->{'container'}->get_all_compara_DnaAlignFeatures(
    $self->species_defs->get_config($self->my_config('species'), 'SPECIES_PRODUCTION_NAME'),
    $self->my_config('assembly'),
    $self->my_config('type'),
    $self->dbadaptor('multi', $self->my_config('db'))
  );
  
  my $target = $self->my_config('target');
  
  $features = [ grep $_->hseqname eq $target, @{$features||[]} ] if $target;
  
  return $features;
}

sub render_text {
  my $self = shift;
  
  my $strand = $self->strand;
  my $strand_flag = $self->my_config('strand');
  
  return if $strand_flag eq 'r' && $strand != -1;
  return if $strand_flag eq 'f' && $strand != 1;

  my $length  = $self->{'container'}->length;
  my $species = $self->my_config('species');
  my $type    = $self->my_config('type');
  my $export;
  
  foreach my $f (@{$self->features||[]}) {
    next if $strand_flag eq 'b' && $strand != $f->hstrand || $f->end < 1 || $f->start > $length;
    
    $export .= $self->_render_text($f, $type, { 
      headers => [ $species ], 
      values  => [ $f->hseqname . ':' . $f->hstart . '-' . $f->hend ]
    }, {
      strand => '.',
      frame  => '.'
    });
  }
  
  return $export;
}

1;
