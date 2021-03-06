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

package Bio::EnsEMBL::GlyphSet::gEVAL_soma;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);
use Data::Dumper;

#==============================================================================
# The following functions can be over-riden if the class does require
# something diffirent - main one to be over-riden is probably the
# features call - as it will need to take different parameters...
#==============================================================================

sub feature_group {
  my( $self, $f ) = @_;  
  my $groupname  = $f->hseqname;
  return $groupname;  
}


sub feature_label {
  my( $self, $f, $db_name ) = @_;
  my ($fraglength) = @{$f->get_all_Attributes('frag_length')}; 
  my ($feat_type)  = @{$f->get_all_Attributes('soma_type')};
  
  my $label = ($feat_type->value eq "aligned") ? $fraglength->value : "";
  return $label;
}


sub feature_title {
  my( $self, $f, $db_name) = @_;
  return $f->hseqname;
}

sub features {
  my ($self) = @_;

  my $method      = 'get_all_DnaAlignFeatures';
  my $db          = $self->my_config('db');
  my @logic_names = @{ $self->my_config( 'logicnames' )||[] };

  $self->timer_push( 'Initializing don', undef, 'fetch' );
  my @results = map { $self->{'container'}->$method($_,undef,$db)||() } @logic_names;
  $self->timer_push( 'Retrieved features', undef, 'fetch' );
  my %results = ( $self->my_config('name') => [@results] );

  return %results;

}



sub href {
### Links to /Location/Genome
  my ($self, $f_ref ) = @_;

  my @F  = @$f_ref;
  my $db = $self->my_config('db');
  
  my $mapname = $F[0][2]->hseqname;
  my $score;

  my $r     = $F[0][2]->seq_region_name.':'.$F[0][2]->seq_region_start.'-'.$F[-1][2]->seq_region_end;
  my ($idx_start, $idx_end) = ( $F[0][2]->extra_data < $F[-1][2]->extra_data ) ? 
      ($F[0][2]->extra_data, $F[-1][2]->extra_data) :
      ($F[-1][2]->extra_data, $F[0][2]->extra_data) ;  
  

  $idx_start = 0 if (!$idx_start);

  my @unaligned_bits;
  foreach my $f (@F){
      my $feat = $$f[2];
      my ($feat_type) = @{$feat->get_all_Attributes('soma_type')};
      $feat_type = $feat_type->value();

      if (!$score && $feat_type eq "aligned"){
	  $score = $feat->score;
      }
      next if ($feat_type ne "unaligned");
      my $idx_range = $feat->extra_data || undef;
      $idx_range =~ s/-/ to /;
      my $size      = ($feat->cigar_string) || undef;
      $size =~ s/M/bp/;
      push @unaligned_bits, "$idx_range ($size)";

  }

  my $unaligned = join(",", @unaligned_bits);

  my $zmenu = {
      'type'          => 'OM',
      'action'        => 'View',
      'r'             => $r,
      'name'          => $mapname,
      'idx_range'     => "$idx_start to $idx_end",
      'score'         => $score,
      'unaligned'     => $unaligned,
      'db'            => $db,
  };



  return $self->_url($zmenu);

}


sub colour_key {
  my( $self, $feature_key ) = @_;
  return $self->my_config( 'sub_type' );
}

## ---- MAIN DRAWING CODE ---- ##
##  FOR NORMAL TRACK SETTING   ##
sub render_normal {
  my $self = shift;
  
  return $self->render_text if $self->{'text_export'};
  
  my $tfh    = $self->{'config'}->texthelper()->height($self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'});
  my $h      = @_ ? shift : ($self->my_config('height') || 8);
  my $dep    = @_ ? shift : ($self->my_config('dep'   ) || 6);
  my $gap    = $h<2 ? 1 : 2;
   
## Information about the container...
  my $strand         = $self->strand;
  my $strand_flag    = $self->my_config('strand');
  my $length         = $self->{'container'}->length();
## And now about the drawing configuration
  my $pix_per_bp     = $self->scalex;
  my $DRAW_CIGAR     = ( $self->my_config('force_cigar') eq 'yes' )|| ($pix_per_bp > 0.2) ;
## Highlights...
  my %highlights = map { $_,1 } $self->highlights;
  my $hi_colour = 'highlight1';

#  print STDERR "RENDER NORMAL (height: $h, strand: $strand, length: $length, ppb: $pix_per_bp) \n";

  if( $self->{'extras'} && $self->{'extras'}{'height'} ) {
      $h = $self->{'extras'}{'height'};
  }

## Get array of features and push them into the id hash via the features call above...
##---------------------------------##
  my %features = $self->features;
##---------------------------------##

  my $db     = 'DATABASE_CORE';
  my $extdbs = $self->species_defs->databases->{$db}{'tables'}{'external_db'}{'entries'};

  my $y_offset        = 0;
  my $features_drawn  = 0;
  my $features_bumped = 0;
  my $label_h         = 0;
  my( $fontname, $fontsize ) ;
    ( $fontname, $fontsize ) = $self->get_font_details( 'outertext' );
 

  foreach my $feature_key ( keys %features ) {
      my %id             = ();
      $self->_init_bump( undef, $dep );
      $self->{'track_key'} = $feature_key;


      foreach my $features ( @{$features{$feature_key}} ) {
	  foreach my $f (
	      map { $_->[2] }
	      sort{ $a->[0] <=> $b->[0] }
	      map { [$_->start,$_->end, $_ ] }
	      @{$features || []}
	      ){
	      my $hstrand  = $f->can('hstrand')  ? $f->hstrand : 1;
	      my $fgroup_name = $self->feature_group( $f );
	      my $s =$f->start;
	      my $e =$f->end;
	      
	      
	      my $db_name = $f->can('external_db_id') ? $extdbs->{$f->external_db_id}{'db_name'} : 'OLIGO';
	      next if $strand_flag eq 'b' && $strand != ( ($hstrand||1)*$f->strand || -1 ) || $e < 1 || $s > $length ;
	      push @{$id{$fgroup_name}}, [$s,$e,$f,int($s*$pix_per_bp),int($e*$pix_per_bp),$db_name];
	  }
      }
            
      my $y_pos;
      my $colour_key     = $self->colour_key( $feature_key );
      my $feature_colour = $self->my_colour( $self->my_config( 'sub_type' ), undef  );
      my $join_colour    = $self->my_colour( $self->my_config( 'sub_type' ), 'join' );
      
      next unless keys %id;

      ##  Now go through featgroup in turn, drawing them. 
      ##   ie the rect feats will fit in to this composite feature, the large box.
      foreach my $i ( sort {
	      @{$id{$b}}     cmp @{$id{$a}}     || 
	      $id{$a}[0][3]  <=> $id{$b}[0][3]  ||
	      $id{$b}[-1][4] <=> $id{$a}[-1][4]
       	      } keys %id) {
	  
	  my @F          = @{$id{$i}}; # sort { $a->[0] <=> $b->[0] } @{$id{$i}};
	  my $START      = $F[0][0] < 1 ? 1 : $F[0][0];
	  my $END        = $F[-1][1] > $length ? $length : $F[-1][1];
	  my $db_name    = $F[0][5];
	  my( $txt, $bit, $w, $th );
	  my $bump_start = int($START * $pix_per_bp) - 1;
	  my $bump_end   = int(($END) * $pix_per_bp);

	  my @high_lights;

	  if( $self->{'show_labels'} ) {
	      my $title                 = $self->feature_label( $F[0][2],$db_name );
	      my( $txt, $bit, $tw,$th ) = $self->get_text_width( 0, $title, '', 'ptsize' => $fontsize, 'font' => $fontname );
	      my $text_end              = $bump_start + $tw + 1;
	      $bump_end                 = $text_end if $text_end > $bump_end;
	  }

	  my $row  = $self->bump_row( $bump_start, $bump_end );
	  if( $row > $dep ) {
	      $features_bumped++;
	      next;
	  }
	  
	  $y_pos     = $y_offset - $row * int( $h + $gap * $label_h ) * $strand;            
	  my $comp_x = $F[0][0]> 1 ? $F[0][0]-1 : 0;

	  my $Composite = $self->Composite({
	      'href'  => $self->href( \@F ),
	      'x'     => $F[0][0]> 1 ? $F[0][0]-1 : 0,
	      'width' => 0,
	      'y'     => 0,
	      'title' => $self->feature_title($F[0][2],$db_name)
					   });
	  my $X = -1e8;

	  $feature_colour = "orange";
	  $hi_colour      = "ffd280";

	  my @unaligned_feats;

	  ## Now go in to each feature of the featgroup to draw the rect, to populate the composite object.
	  for (my $j=0; $j < @F; $j++ ) {
	      my $f               = $F[$j];
	      my( $s, $e, $feat ) = @$f;
	      my $feat_strand     = $feat->strand;

	      #next if int($e * $pix_per_bp) <= int( $X * $pix_per_bp );	      
	      $features_drawn++;
	      
	      my $START = $s < 1 ? 1 : $s;
	      my $END   = $e > $length ? $length : $e;
	      $X        = $END;
	
	      #print STDERR  "FEAT STRAND: $feat_strand (hs: hstrand, st:  $strand, $feat)\n";
	      my ($feat_type) = @{$feat->get_all_Attributes('soma_type')};
	      $feat_type = $feat_type->value();
	      my $text_colour = "black";

	      if ($feat_type =~ /upstream|downstream/){
		  $feature_colour = "ffebc4";
	      }
	      else {
		  if ($feat->hstrand == 1){
		      $feature_colour = "orange";
		  }
		  else {
		      $feature_colour = "FE642E";
		  }
	      }

	
	      if ($feat_strand == 1 ){  
		  $Composite->push($self->Rect({
		      'x'          => $START-1,
		      'y'          => 0,
		      'width'      => $END-$START+1,
		      'height'     => $h,
		      'colour'     => $feature_colour,
		      'absolutey'  => 1,
					       }));
		  

		  $Composite->push($self->Line({
		      'x'          => $START,
		      'y'          => 0,
		      'width'      => 0,#($F[$j + 1][ 0 ] - $F[ $j ][ 1 ] + 1)/2,
		      'height'     => $h,
		      'colour'     => "black",
		      'absolutey'  => 1,
					       }));
		  
		  $Composite->push($self->Line({
		      'x'          => $F[$j][ 1 ],
		      'y'          => 0, # $y_pos,
		      'width'      => 0,#($F[$j + 1][ 0 ] - $F[$j][1 ] + 1)/2,
		      'height'     => $h,
		      'colour'     => "black",
		      'absolutey'  => 1,
					       }));

		  ## Add frag size to each bit.
		  my $tmp_textwidth = [$self->get_text_width( 0, $self->feature_label($feat), '', 'font' => $fontname, 'ptsize' => $fontsize* 0.9 )]->[2] / $pix_per_bp;
		  if ($tmp_textwidth < ($END - $START +1)){
		      
		      $Composite->push($self->Text({
			  'font'      => $fontname,
			  #'fontsize'  => $fontsize * 0.9,
			  'colour'    => $text_colour,
			  'ptsize'    => $fontsize * 0.9,
			  'text'      => $self->feature_label($feat),
			  'halign'    => 'center',
			  'valign'    => 'center',
			  'textwidth' => $tmp_textwidth*$pix_per_bp,
			  'x'         => $START - 1, 
			  'y'         => 0,
			  'width'     => $END-$START+1,
			  'height'    => $h,
			  'absolutey' => 1
						   }));
		      

		  }		  		  
	      }

	      if ($feat_type eq "unaligned"){
		  
		  my $scale = ($length>1000000) ? 10000 : 5000;
		  $scale = 3000 if ($length <= 500000);
		  $scale = 1800 if ($length <= 200000);
		  $scale = 500  if ($length <= 100000);
		  $scale = 50   if ($length <= 5000);

		  

		  my $newcomposite = $self->Composite({
		      'x'     => 0,
		      'width' => $length,
		      'y'     => $h,
						      });
		  #my $newcomposite_start = 1000;
		  $newcomposite->push($self->Poly({
                    'points' => [ $START, $h,
				  $START-$scale, 0 ,
				  $START+$scale, 0],
		    'colour'       => "green",
                    'bordercolour' =>"black",
		    'absolutey'    => 1,

						   }) );

		  $newcomposite->y( $newcomposite->y + $y_pos );
		  push @unaligned_feats, $newcomposite;
		  
		  #my ($unalign_feat) = @{$feat->get_all_Attributes('soma_unaligned')};
		  #my $unaligned_bits = ($unalign_feat) ? $unalign_feat->value : undef;
		  
		  #push @unaligned_features, $unaligned_bits;
		  
	      }
	  }
	  
	  $Composite->bordercolour("black");
	  $Composite->y( $Composite->y + $y_pos );
	  $self->push( $Composite );

	  if (@unaligned_feats > 0){
	      foreach my $unalignfeat (@unaligned_feats){
		  $self->push($unalignfeat);
	      }
	  }
	  

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
          if(exists $highlights{$i}) {
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

1;
