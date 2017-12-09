#-----------------------------------------------------------
# Web.pm - Web Misc Functions
#
# CONTAINS:
#
#
#-----------------------------------------------------------

package WebFrame::Web ;

use Exporter ();
use WebFrame::Debug ;
use WebFrame::Sys ;

@ISA    = qw( Exporter );
@EXPORT = qw( file_upload version get_query version fmt_date_time_str prev_next);

#-----------------------------------------------------------
# File Upload
#-----------------------------------------------------------
sub file_upload {

  my ($filename,$saved_filename) = @_;

  unless ( open (OUTFILE,">$saved_filename") ) 
  { 
    debug ("Cannot Open $saved_filename");
    return 0;
  }

  binmode(OUTFILE);
  binmode($filename);

  while ($bytesread=read($filename,$buffer,1024)) {
          print OUTFILE $buffer;
  }

  close OUTFILE;

  chmod( 0750, $saved_filename ); 

  return 1;
}

#-----------------------------------------------------------
# version()
#
# Returns the version of an application by reading the directory.
#-----------------------------------------------------------
sub version {

 require Cwd;
 import Cwd fastcwd ;

 my $dir = fastcwd();

 $dir =~ /\/([^\/]*)$/ ;
 my $ver = $1;

 return ($ver);

}

#-----------------------------------------------------------
# get_query()
#
# Returns the query hsh.  Makes assumption that a CGI obj
# is created and reference is passed
#-----------------------------------------------------------
sub get_query {

 my $obj_ref = shift @_ ;

 my %hsh;

 my $class = ref($obj_ref) ;

 if ( not ref($obj_ref) =~ "CGI") { debug("Wrong Arguement Type") }  ;

 tie (%hsh, $class , $obj_ref );

 # Give form elements with name action_\w special meaning
 # This allow us to give buttons both a name and value and label.
 # Kludge? Perhaps . . .
 my ($action_key) = grep /^action_/ , keys %hsh ;
 if ( $action_key ) {

    $action_key =~ /^action_(.*)/  ;

    # remove the .x or .y part if the submit input is an image
    my $func = $1 ;
    $func =~ s/\.\w+// ;

    $hsh{'ACTION'} = $func ;
 }

 # Be sensitive to use
 if ( wantarray ) { return %hsh }
 return (\%hsh) ;

}


#--------------------------------------------
# Format date and time for weather data files
#---------------------------------------------
sub fmt_date_time_str {

  my $tick = shift;
  my $date_str;

  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($tick);

   $year_str = $year % 100  ;
   $year_str  = sprintf('%02d',$year_str);

   $mday_str  = sprintf('%02d',$mday);

   $mon++;
   $mon_str = sprintf('%02d',$mon);
   $hour    = sprintf('%02d',$hour);
   $min     = sprintf('%02d',$min);
   $sec     = sprintf('%02d',$sec);

   $date_str = "$mon_str/$mday_str/$year_str";
   $time_str = "${hour}:${min}:${sec}";

   return ($date_str , $time_str);

}

#--------------------------------------------
# Get next and prev indexes from a list
# Usage: ($pidx,$nidx) = prev_next(@lst,$elem);
#---------------------------------------------
sub prev_next {

   my $i;

   my @lst = @_;

   my $elem = pop(@lst);  # pop off the index argument

   my $str = join('',@lst);

   if($str =~ /\D+/g){
      foreach (@lst){ if($elem eq $_){ last } $i++ }  # test as string
   }else{
      foreach (@lst){ if($elem == $_){ last } $i++ }  # test as number
   }

   my $prev = $i - 1;
   my $next = $i + 1;

   if($prev < 0     ){ $prev = $#lst }
   if($next > $#lst ){ $next = 0     }

   return($prev,$next);

}
$positive_note = 1;
