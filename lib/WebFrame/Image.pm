package WebFrame::Image;

use Exporter ();
use WebFrame::Debug ;

@ISA = qw( WebFrame::Debug Exporter );
@EXPORT = qw( check_img_size img_reducer image_rotate);

#-------------------------------------------------
#  sub check_img_size
#
#  This sub will take a gif or jpg and
#  reduce the size if either the X or Y parameter
#  is greater that a max X or Y value.
#
#  inputs: 1. filename of gif or jpg
#          2. max X
#          3. max Y
#
#  returns: 0 if success
#           1 if failed
#
#  This sub will keep the original proportions
#  and max either the X or the Y which ever is
#  greater.
#
#  1/8/99   BFL
#-------------------------------------------------

 $t_path = $ENV{PATH};
 $ENV{PATH} = $t_path . ":/usr/local/bin:/usr/home/htd/bin";

sub check_img_size {

 my ($fspec, $maxX, $maxY, $qual, $nfspec) = @_;

 use Image::Size;

 ($x, $y) = imgsize($fspec);

 $fspec =~ /.*?\.(.*)$/;
 $ext = $1;

 if( ($x > $maxX)  || ($y > $maxY) || ($ext eq "gif") ) {
    $ans = &img_reducer($fspec, $maxX, $maxY, $qual, $nfspec);
 }else{
    if ( $nfspec ) { `cp $fspec $nfspec`;}
 }
 return($ans);

1;
}




#-------------------------------------------------
#  sub img_reducer
#
#  This sub will take a gif or jpg and
#  create a jpg thumbnail.
#
#  inputs: 1. filename of gif or jpg original
#          2. pixel size of desired X value
#          3. pixel size of desired Y value
#          4. quality factor with 100 being best
#          5. output filename of new jpeg.
#
#  returns:  error status
#
#
#  This sub will keep the original proportions
#  and max either the X or the Y which ever is
#  greater.
#
#  1/6/99   BFL
#-------------------------------------------------


sub img_reducer {

 my ($fspec, $sizex, $sizey, $qual, $nfspec) = @_;

 $fspec =~ /(.*)\.(.*)$/;
 $base = $1;
 $type  = $2;

 if ( !$nfspec ) { $nfspec = "$base.jpg"; }

 if ( $type eq "gif" ) { $cmd = "giftopnm $fspec 2>/dev/null"; }
 if ( $type eq "jpg" ) { $cmd = "djpeg $fspec 2>/dev/null";    }
 my $pnm = `$cmd`;

 $t = open PNMTOTHUMB,"| pnmscale -xy $sizex $sizey | cjpeg -qual $qual >$nfspec" || die "Cannot open for $nfspec";
 print PNMTOTHUMB $pnm;
 close PNMTOTHUMB;

 return($?);
1;
}

#-----------------------------------------------------
# sub image_rotate
#
# This routine will rotate an image by +90 or -90
# and store the results in the same filename
#
#  inputs: 1. filename of gif or jpg original
#          2. angle to rotate
#          3. new filename to saveth results
#
#  returns:  error status
#------------------------------------------------------
sub image_rotate {

 my ($fspec, $angle, $nfspec) = @_;

 ($base, $type) = split /\./, $fspec;

 if ( $type eq "gif" ) { $cmd = "giftopnm $fspec 2>/dev/null"; }
 elsif ( $type eq "jpg" ) { $cmd = "djpeg $fspec 2>/dev/null";    }
 else{ $status = -1; return($status); }


 my $pnm = `$cmd`;


 open PNMTOTHUMB,"| pnmrotate -noantialias $angle | cjpeg -qual 100 >$nfspec";
 print PNMTOTHUMB $pnm;
 close PNMTOTHUMB;


 return($?);

1;
}
