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

package Bio::EnsEMBL::GlyphSet::gEVAL_selfcomp;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

#-------------------------------#
# 
#  Glyph for displaying selfcomp
#  track results.
#
#  wc2@sanger.ac.uk
#
#-------------------------------#

#-------------------#
# Feature calls...
#  fetching features
#  and attributes.
#--------------------#
sub feature_group {
  my( $self, $f ) = @_;
  return $f->hseqname;    ## For core features this is what the sequence name is...
}

sub feature_label {
  my( $self, $f, $db_name ) = @_;
  return $f->hseqname;
}

sub feature_title {
  my( $self, $f, $db_name ) = @_;
  $db_name ||= 'External Feature (tm)';
  return "$db_name ".$f->hseqname;
}

sub features {
  my ($self) = @_;

  my $method      = 'get_all_'.( $self->my_config('object_type') || 'DnaAlignFeature' ).'s';
  my $db          = $self->my_config('db');
  my @logic_names = @{ $self->my_config( 'logicnames' )||[] };

  $self->timer_push( 'Initializing don', undef, 'fetch' );
  my @results = map { $self->{'container'}->$method($_,undef,$db)||() } @logic_names;
  $self->timer_push( 'Retrieved features', undef, 'fetch' );
  my %results = ( $self->my_config('name') => [@results] );

  return %results;
}


#-----------------------#
# href
#  data sent to create
#  selfcomp zmenu.
#-----------------------#
sub href {
  my( $self, $f ) = @_;
  my $r            = $f->seq_region_name.':'.$f->seq_region_start.'-'.$f->seq_region_end;  
  my $shown_region = $self->{'config'}->core_objects->{'location'}->param('r');
  
  return $self->_url({
    'action'     => 'Selfcomp', #'Genome',
    'ftype'      => $self->my_config('object_type') || 'DnaAlignFeature',
    'r'          => $shown_region,
    'region'     => $shown_region, 
    'logic_name' => @{ $self->my_config( 'logicnames' )||[] }[0], 
    'id'         => $f->display_id,
    'dbid'       => $f->dbID,
    'db'         => $self->my_config('db'),
  });
}

#==============================================================================
# Next we have the _init function which chooses how to render the
# features...
#==============================================================================

sub render_unlimited {
  my $self = shift;
  $self->render_normal( 1, 1000 );
}

sub render_stack {
  my $self = shift;
  $self->render_normal( 1, 40 );
}

sub render_half_height {
  my $self = shift;
  $self->render_normal( $self->my_config('height')/2 || 4);
}

sub colour_key {
  my( $self, $feature_key ) = @_;
  return $self->my_config( 'sub_type' );
}

sub render_labels {
  my $self = shift;
  $self->{'show_labels'} = 1;
  $self->render_normal();
}



#--------------------------#
# render_normal
#  The main drawing code
#  for the glyph.
#--------------------------#
sub render_normal {
  my $self = shift;
 
  return $self->render_text if $self->{'text_export'};
  
  my $tfh    = $self->{'config'}->texthelper()->height($self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'});
  my $h      = @_ ? shift : ($self->my_config('height') || 8);
  my $dep    = @_ ? shift : ($self->my_config('dep'   ) || 8);
  my $gap    = $h<2 ? 1 : 2;   
## Information about the container...
  my $strand         = $self->strand;
  my $strand_flag    = $self->my_config('strand');

  my $length = $self->{'container'}->length();
## And now about the drawing configuration
  my $pix_per_bp     = $self->scalex;
  my $DRAW_CIGAR     = ( $self->my_config('force_cigar') eq 'yes' )|| ($pix_per_bp > 0.2) ;
## Highlights...
  my %highlights = map { $_,1 } $self->highlights;
  my $hi_colour  = 'highlight1';


  if( $self->{'extras'} && $self->{'extras'}{'height'} ) {
    $h = $self->{'extras'}{'height'};
  }

## Get array of features and push them into the id hash...
  my %features = $self->features;

  #get details of external_db - currently only retrieved from core since they should be all the same
  my $db = 'DATABASE_CORE';
  my $extdbs = $self->species_defs->databases->{$db}{'tables'}{'external_db'}{'entries'};

  my $y_offset = 0;

  my $features_drawn  = 0;
  my $features_bumped = 0;
  my $label_h = 0;
  my( $fontname, $fontsize ) ;
  if( $self->{'show_labels'} ) {
    ( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
    my( $txt, $bit, $w,$th ) = $self->get_text_width( 0, 'X', '', 'ptsize' => $fontsize, 'font' => $fontname );
    $label_h = $th;
  }
  
  foreach my $feature_key ( $strand < 0 ? sort keys %features : reverse sort keys %features ) {
    $self->_init_bump( undef, $dep );
    my %id               = ();
    $self->{'track_key'} = $feature_key;

    foreach my $features ( @{$features{$feature_key}} ) {
      foreach my $f (
        map { $_->[2] }
        sort{ $a->[0] <=> $b->[0] }
        map { [$_->start,$_->end, $_ ] }
        @{$features || []}
      ){
        my $hstrand     = $f->can('hstrand')  ? $f->hstrand : 1;
        my $fgroup_name = $self->feature_group( $f );
        my $s           = $f->start;
        my $e           = $f->end;

        my $db_name = $f->can('external_db_id') ? $extdbs->{$f->external_db_id}{'db_name'} : 'OLIGO';
        next if $strand_flag eq 'b' && $strand != ( ($hstrand||1)*$f->strand || -1 ) || $e < 1 || $s > $length ;
        push @{$id{$fgroup_name}}, [$s,$e,$f,int($s*$pix_per_bp),int($e*$pix_per_bp),$db_name];
      }
    }
    
    
    ## Now go through each feature in turn, drawing them
    my $y_pos;
    my $colour_key     = $self->colour_key( $feature_key );
    my $feature_colour = "red1";

    $hi_colour      = "ffe8cc";

    my $regexp = $pix_per_bp > 0.1 ? '\dI' : ( $pix_per_bp > 0.01 ? '\d\dI' : '\d\d\dI' );

    next unless keys %id;
    foreach my $i ( sort {
	@{$id{$b}}   <=> @{$id{$a}}     || # added by wc2, to push the big hits as close to ctg track
      $id{$a}[0][3]  <=> $id{$b}[0][3]  ||
      $id{$b}[-1][4] <=> $id{$a}[-1][4]
    } keys %id){
      my @F          = @{$id{$i}}; # sort { $a->[0] <=> $b->[0] } @{$id{$i}};
      my $START      = $F[0][0] < 1 ? 1 : $F[0][0];
      my $END        = $F[-1][1] > $length ? $length : $F[-1][1];
      my $db_name    = $F[0][5];
      my( $txt, $bit, $w, $th );
      my $bump_start = int($START * $pix_per_bp) - 1 ;
      my $bump_end   = int(($END) * $pix_per_bp);

      my @high_lights;

      if( $self->{'show_labels'} ) {
        my $title                 = $self->feature_label( $F[0][2],$db_name );
        my( $txt, $bit, $tw,$th ) = $self->get_text_width( 0, $title, '', 'ptsize' => $fontsize, 'font' => $fontname );
        my $text_end = $bump_start + $tw + 1;
        $bump_end                 = $text_end if $text_end > $bump_end;
      }
      my $row        = $self->bump_row( $bump_start, $bump_end );
      if( $row > $dep ) {
        $features_bumped++;
        next;
      }
      $y_pos = $y_offset - $row * int( $h + $gap * $label_h ) * $strand;
      
      my $sa           = $self->{'container'}->adaptor;
      my $feat_srstart = $F[0][2]->seq_region_start;
      my $feat_srend   = $F[-1][2]->seq_region_start;
      
      $feature_colour = &colour_code($sa, $self->{'container'}, $i, $feat_srstart, $feat_srend);
      
      my $comp_x = $F[0][0]> 1 ? $F[0][0]-1 : 0;

      my $Composite = $self->Composite({
        'href'  => $self->href( $F[0][2] ),
        'x'     => $F[0][0]> 1 ? $F[0][0]-1 : 0,
        'width' => 0,
        'y'     => 0,
        'title' => $self->feature_title($F[0][2],$db_name)
      });
      my $X = -1e8;
      foreach my $f ( @F ){ ## Loop through each feature for this ID!
        my( $s, $e, $feat ) = @$f;
        next if int($e * $pix_per_bp) <= int( $X * $pix_per_bp );
	my $feat_strand = $feat->strand;

        $features_drawn++;

	my $START = $s < 1 ? 1 : $s;
	my $END   = $e > $length ? $length : $e;
	$X = $END;
	
	my (@pair1, @pair2, @pair3);
	
	if ($feat_strand == 1 ){   #draw triangle either downstream or upstream.

	  $Composite->push($self->Rect({
	    'x'          => $START-1,
	    'y'          => 0,
	    'width'      => $END-$START+1,
	    'height'     => $h,
	    'colour'     => $feature_colour,
	    'absolutey'  => 1,
	  }));
     
	}
	elsif ($feat_strand == -1 ){
	  
	  $Composite->push($self->Rect({
	    'x'          => $START-1,
	    'y'          => 0, # $y_pos,
	    'width'      => $END-$START+1,
	    'height'     => $h,
	    'colour'     => $feature_colour,
	    'absolutey'  => 1,
	  }));

	}
      }      
      my $feat_start = $F[0][2]->seq_region_start;
      my $feat_end   = $F[-1][2]->seq_region_start;
    
      if( $h > 1 ) {
        $Composite->bordercolour($feature_colour);
      }
      
      $Composite->y( $Composite->y + $y_pos );
      $self->push( $Composite );

      if( $self->{'show_labels'} ) {
        $self->push( $self->Text({
          'font'      => $fontname,
          'colour'    => $feature_colour,
          'height'    => $fontsize,
          'ptsize'    => $fontsize,
          'text'      => $self->feature_label($F[0][2],$db_name),
          'title'     => $self->feature_title($F[0][2],$db_name),
          'halign'    => 'left',
          'valign'    => 'center',
          'x'         => $Composite->{'x'},
          'y'         => $Composite->{'y'} + $h + 2,
          'width'     => $Composite->{'x'} + ($bump_end-$bump_start) / $pix_per_bp,
          'height'    => $label_h,
          'absolutey' => 1
        }));
      }
      if( exists $highlights{$i} ) {
        $self->unshift( $self->Rect({
          'x'         => $Composite->{'x'} - 1/$pix_per_bp,
          'y'         => $Composite->{'y'} - 1,
          'width'     => $Composite->{'width'} + 2/$pix_per_bp,
          'height'    => $h + 2,
          'colour'    => $hi_colour,
          'absolutey' => 1,
        }));
      }
    }
    
    $y_offset -= $strand * ( ($self->_max_bump_row ) * ( $h + $gap + $label_h ) + 6 );
  }
  $self->errorTrack( "No features from '".$self->my_config('name')."' in this region" )
    unless( $features_drawn || $self->get_parameter( 'opt_empty_tracks')==0 );

  if( $self->get_parameter( 'opt_show_bumped') && $features_bumped ) {
    my $y_pos = $strand < 0
              ? $y_offset
              : 2 + $self->{'config'}->texthelper()->height($self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'})
              ;
    $self->errorTrack( sprintf( q(%s features from '%s' omitted), $features_bumped, $self->my_config('name')), undef, $y_offset );
  }
  $self->timer_push( 'Features drawn' );
## No features show "empty track line" if option set....
}

#-------------------#
# render_text
#  as advertised, 
#  renders text.
#-------------------#
sub render_text {
  my $self = shift;
  
  my $strand   = $self->strand;
  my %features = $self->features;
  my $method   = $self->can('export_feature') ? 'export_feature' : '_render_text';
  my $export;
  
  foreach my $feature_key ($strand < 0 ? sort keys %features : reverse sort keys %features) {
    foreach my $f (@{$features{$feature_key}}) {
      foreach (map { $_->[2] } sort { $a->[0] <=> $b->[0] } map { [ $_->start, $_->end, $_ ] } @{$f||[]}) {
        $export .= $self->$method($_, $self->my_config('caption'), { 'headers' => [ 'id' ], 'values' => [ $_->can('hseqname') ? $_->hseqname : $_->can('id') ? $_->id : '' ] });
      }
    }
  }
  
  return $export;
}


#----------------------------------#
# colour_code
#  wc2 0912: added to colour code 
#  selfcomp results based on hit 
#  location.
#----------------------------------#
sub colour_code {

    my ($sa, $query_slice, $hitname, $srstart, $srend) = @_;
    
    return "red1" if ( !($sa->db()->get_CoordSystemAdaptor->fetch_by_name('clone')) );

    my $hitslice = $sa->fetch_by_region('clone', $hitname) || undef;

    return "red1" if (!$hitslice);

    my $proj_slice = @{$hitslice->project('toplevel')}->[0]->to_Slice;
    
    my $proj_slicename    = $proj_slice->seq_region_name;
    my $query_slicename   = $query_slice->seq_region_name;
    
    #highlight zebrafish Haplotype chr hits
    my $haplohit;
    if ($proj_slicename =~ /H/){
	(my $ref_chr = $proj_slicename) =~ s/H_//;
	
	$haplohit = 1 if ($ref_chr eq $query_slicename);
    }

    if ($proj_slicename eq $query_slicename){
	
	# default arbirtray windown size of 500kb flanking. Reasoning size of a BAC/gaps.
	my $window = 500000;
	my $overall_slice = $sa->fetch_by_region('toplevel', $query_slicename, $srstart - $window, $srend + $window);
    
	my @clones = map {$_->to_Slice->seq_region_name} @{$overall_slice->project('clone')};
	
	my $result = grep (/$hitname/, @clones);

	return "#CB7410" if (!$result);

	return "#00C628";
    }
    elsif ($haplohit) {
	return "#1A54FF"; 
    }
    else {
	return "#D02828";
    }

}

1;
