#-----------------------------------------------------------
# Sys.pm - System oriented tools
#
# CONTAINS:
#
#   @lst = ls($dir_name)
#   @lst - read_file($fspec)
#   write_file($fspec, @lst)
#   rotate_files($fspec, $num)
#
#   safe_read($fspec)
#   safe_write($f,$ref)
#
#-----------------------------------------------------------

package WebFrame::Sys;

use Exporter ();
use WebFrame::Debug ;

@ISA = qw( WebFrame::Debug Exporter );
@EXPORT = qw( ls read_file write_file rotate_files safe_read safe_write );

#--------------------------------------------------
#  Returns a dir list.  Optional filter input
#--------------------------------------------------
sub ls {

  my ($dir_name, $filter) = @_;
  my @lines ;

  opendir (DID, "$dir_name") || debug ("Can't open $dir_name");
  @lines = readdir (DID);

  # Remove . and ..
  @lines = grep !/^\.\.?$/,@lines ;

  if ($filter) { @lines = grep /$filter/, @lines }

  close (DID);

  if ( wantarray ) { return @lines }
  return (\@lines) ;

}

#--------------------------------------------------------
#  This sub just reads the file into an array and returns
#--------------------------------------------------------
sub read_file {

  my $filename = shift @_;

  open (FID, $filename) || debug ("Can't open $filename");

  @data = <FID>;

  close (FID);

  if ( wantarray ) { return @data }
  return(\@data);

}

#--------------------------------------------------------
#  This sub just writes the array to a file and returns
#--------------------------------------------------------
sub write_file {

  my $filename = shift @_;

  open (FID, ">$filename") || debug ("Can't open $filename");

  if ( ref($_[0]) ) { print FID @{$_[0]} }

  else              { print FID @_        }
  close (FID);

}

#--------------------------------------------------------
#  This sub rotates a set of log files
#  Note: Special logic to prevent propagating missing or
#  zero length files.
#--------------------------------------------------------
sub rotate_files {

 my $fullname = shift @_;
 my $num      = shift @_;

 use File::Copy;

 my ($peek, $from, $next);
 for (my $i = $num; $i >= 0; $i-- )
 {
    $next = "$fullname.$i";

    my $j = $i - 1;
    if ( $j >= 0 ) { $from = "$fullname.$j" } else { $from = $fullname }
    unless ( -s $from ) { next }   # Do not do anything if the file does not exist

    my $k = $j - 1;
    if ( $k >= 0 ) { $peek = "$fullname.$k" } else { $peek = $fullname }
    unless ( -s $peek ) { next }   # Do not do anything if there is no replacement

    move( $from, $next) || debug("File Move Failed $from -> $next : $!");
 }

}

#--------------------------------------------------------
# Reads in stringified perl structures
# Returns a reference
#--------------------------------------------------------
sub safe_read
{
   my $fspec = shift;

   require Safe;
   my $safe = new Safe;

   my $rtn = $safe->rdo($fspec); 
   if ( $@ ) { debug "Error with safe_read $fspec $@" };

   return $rtn;
}

#--------------------------------------------------------
# Writes out perl structures (provided via a reference)
#--------------------------------------------------------
sub safe_write
{
   my $fspec = shift;
   my $ref   = shift;

   require Data::Dumper;
   import Data::Dumper qw(Dumper);

   my $str = Dumper($ref);

   write_file($fspec, $str);

   return 1;
}



$positive_note = 1;
