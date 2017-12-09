#-----------------------------------------------------------
# Save.pm - Save Tools
#
#    parse_read($filespec)
#    parse_save($filespec, %hsh);
#
#-----------------------------------------------------------

package WebFrame::Save;

use Exporter ();
use WebFrame::Debug ;
use WebFrame::Sys ;
use bytes;

@ISA    = qw( WebFrame::Sys WebFrame::Debug Exporter );
@EXPORT = qw( parse_read parse_save  );


###########################################################
# This routine parses the file given by a filespec
# in the parse format
#
# i.e.  key { value } format.
#
###########################################################
sub parse_read {

  my %Hsh ;

  my $k ;
  my $t ;

  open (PARSE_FID, "<$_[0]") || debug("Unable to open $_[0]");
  my @lst = grep {!/^\s*#.*$/} <PARSE_FID>;
  $long_line = join "", @lst ;

  while ( $long_line =~ /\s*(.+?)\s*{(.*?)}/gs ) {

     $k = $1 ;    $t = $2 ;
     $t =~ s/^\s+//;
     $t =~ s/\s+$//;

     $t =~ s/§/}/g;

     $Hsh{$k} = $t ;

  }

  close PARSE_FID;

  #
  # Test code ...
  #
  #foreach $k (keys %Hsh )  {
  #    print "key: $k \n";
  #    print "value: $Hsh{$k} \n";
  #}

  if ( wantarray ) { return %Hsh }
  return \%Hsh ;

} # End parse_read()


###########################################################
#
# This writes a file in the parse format given a hash.
#
###########################################################
sub parse_save {

  my $filespec = shift @_;

  my %hsh ;
  my $str ;

  # Be sensitive baby . . .
  if ( ref($_[0]) ) {

     # Note: using default variables speeds things up a bit
     foreach ( keys %{ $_[0] } ) {

        $_[0]->{$_} =~ s/\}/§/g;
        $str .= "$_ \{ ${ $_[0] }{$_} \} \n" ;
     }

  }else {

     %hsh = @_ ;
     foreach ( keys %hsh ) {

        $hsh{$_} =~ s/}/§/g;
        $str .= "$_ \{ $hsh{$_} \} \n" ;

     }

  }

  write_file($filespec, [ $str ]);

} # End parse_save

$positive_note = 1;
