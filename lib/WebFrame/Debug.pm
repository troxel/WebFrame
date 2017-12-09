#-----------------------------------------------------------
# Debug.pm - Debug and Print Debug Info Tools
#
# CONTAINS:
#
#
#-----------------------------------------------------------

package WebFrame::Debug;

use Exporter ();

@ISA = qw( Exporter );
@EXPORT = qw( debug error_page );

# Default Values
$eol           = "\n";
$seperator_str = "--------------------";
$greeting_str  = "Error! ";

$trace_flg = 1;
$time_flg  = 1;
$stop_flg  = 0;

$email = "";
$log_fspec = "";

sub debug
{

  my $header_str ;
  my $trace_str ;
  my $time_str ;
  my $arg_str ;

  my $size ;

  # Are we in a CGI mood . . .
  my $html_flg = $ENV{'SERVER_SOFTWARE'} ;
  if ( $html_flg ) {

       if ( ! $header_flg ) {

          $header_str .= "Content-type: text/html\n\n" ;

          $start_pre = "<pre>";
          $stop_pre  = "</pre>";

          $header_flg= 1
       }

       $eol = "\n";
  }


  # Are we in a detailed mood . . .
  if ($trace_flg) {

     $i = 0 ;

     while ( ($pck, $file , $line , $subname, $hasargs , $wantarray) = caller($i++) ) {
        if ($file =~ /Registry/) {last} # Mod_perl is messy skip it. . .

        $trace_str .= "$subname in $file at line $line Args $hasargs $eol";
     }
  }

  # Do we care about the time
  if ($time_flg) {
     $time_str = localtime(time) . " ";
  }


  require 'Data/Dumper.pm'; import Data::Dumper Dumper;

  $Data::Dumper::Indent = 1;
  $Data::Dumper::Terse = 1;

  # Expand out msg via context
  foreach $arg (@_)
  {
    $arg_str .=  Dumper($arg);
  }

  if ( $email )     { }
  if ( $log_fspec ) { }

  print "${header_str}${start_pre}${time_str}${greeting_str}${arg_str}${seperator_str}${eol}${trace_str}${stop_pre}";

  if ( $stop_flg ) { exit }
}

sub error_page
{

require HTML::Entities;

my @lst;
foreach (@_[0..2])
{
   push @lst, HTML::Entities::encode(shift @_);
}

my $page = "
<html>
  <head>
    <title>WebFrame Error</title>
  </head>
  <body bgcolor=#007770 topmargin=3 marginheight=3>
  <br><center>
  <b>$lst[0]
  <br><br>
  $lst[1]
  <br><br>
  $lst[2]
  </body>
</html>
";
print "Content-type: text/html\n\n";

print $page;

exit;

}


sub hsh_str {

    my $str ;

    foreach ( keys %{$_[0]} ) {

        if ( ref(${$_[0]}{$_}) eq "HASH") {

           $str .= "$seperator_str ${eol}HOH Key { $_ }  $eol" ;
           $str .= hsh_str(${$_[0]}{$_}) ;

        }else{

           $str .= " $_ = " . ${$_[0]}{$_} . $eol ;
        }

    }

    return $str ;
}
$positive_note = 1;

__DATA__
