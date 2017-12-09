package WebFrame;

use Exporter;

our @ISA = qw(Exporter);

my @var_lst = qw($Query %Query %Cookie_in %Cookie_out %Ssn $Ssn %Dir %Url %Data %Error %Enode );
my @sub_lst = qw(do_callback send_now send_minimal);

our @EXPORT = (@var_lst, @sub_lst);

$WebFrame::VERSION ='5.1';

# Global Exported Data Structures

our %Query;
our $Query;
our %Cookie_in;
our %Cookie_out;
our %Data;
our %Dir;

# Include our friends
use WebFrame::Web  ;
use WebFrame::Hsh  ;
use WebFrame::Sys  ;
use WebFrame::Save ;
use WebFrame::TemplateRex;
use WebFrame::Ssn;

use WebFrame::Debug;

use CGI qw(-nosticky);
use CGI::Carp qw(fatalsToBrowser);

$Query = new CGI;

require File::Basename ;  import File::Basename  ;

# Get cookies
foreach ( $Query->cookie() )
{
  my @lst =  $Query->cookie("$_");

  if ( $#lst ) { $Cookie_in{"$_"} = { @lst } }
  else         { $Cookie_in{"$_"} = $lst[0]  }
}

# Get query hash
%Query = get_query($Query);

# Common directories
$Dir{'root'} = $ENV{'DOCUMENT_ROOT'} ;

if ( -e $ENV{'home_wframe'} ) { $Dir{'home_wframe'} = $ENV{'home_wframe'} }
else { $Dir{'home_wframe'} = '/var/www' } 

# Get the relative path and query string
($Dir{'rel'}, $query_str) = $ENV{'REQUEST_URI'} =~ /\/([^?]*)\?*(.*)/;
$Dir{'rel'} =~ s/\/$//; # Remove trailing slash

# Directories ending in "manager" are special manager indicators
if ( $Dir{'rel'} =~ /manager$/i ) { $Dir{'rel'} =~ s/([^\/]*manager)$//; $Dir{'man_mode'} = 1 }

# Extract the file part of the relative url
if ( -f "$Dir{root}/$Dir{rel}" ) { $Dir{'rel'} =~ s/\/(.*)?$//; $Dir{'file'} = $1 }

$Dir{'src'} = "$Dir{root}/$Dir{rel}";

#- - - - - - - - - Experimental Code - - - - - - - - - -#
if (-e "$Dir{src}/.enode")  { %Enode = parse_read("$Dir{src}/.enode") }

if ($Enode{'Dir_rel'})
{
   $Dir{rel} = $Enode{'Dir_rel'};
   $Dir{src} = "$Dir{root}/$Dir{rel}";
}
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -#

$Dir{'templates'} = "$Dir{'src'}/templates";

my $proto = "http";
if    ( $ENV{'SSL_PROTOCOL'}  )  { $proto = 'https' }
elsif ( $ENV{'HTTPS'} =~ /on/i ) { $proto = 'https' }

$Url{'root'} = "$proto://$ENV{'SERVER_NAME'}";
$Url{'src'}  = "$Url{root}/$Dir{rel}";


# Get version and application from dir string
my @lst = split /\// , $ENV{'SCRIPT_FILENAME'};

my $Application = $lst[$#lst-2];
my $Version     = $lst[$#lst-1];

# Generate and get the default standard global session
$Ssn = new WebFrame::Ssn( 'name'=>'Ssn' );
%Ssn = $Ssn->get_ssn( 'name'=>'Ssn' );

#------------------------------------------------------------
# End Init, Time for some action
#------------------------------------------------------------

sub do_callback
{

 my $func = "cb_default";
 if ( $Query{'ACTION'} ) { $func = "cb_$Query{'ACTION'}" }

 my ($package,$filename,$line) = caller;

 $func = $package . "::" . $func;

 if (exists &{$func} ) { $rtn =  &{$func}() }
 else                  { $rtn =  &cb_show_help() }

 return $rtn;

}

#------------------------------------------------------------
# O.K. here is where the fat lady sings
#------------------------------------------------------------
sub send_now
{
  my $str = shift @_;
  if ( ref $str ) { $str = $$str }

  my @hdr_opt_lst = @{ shift @_ };
  
  # Build a cookie list out of the global cookie hash
  my @cookie_lst;
  foreach (keys %Cookie_out) { push @cookie_lst, $Cookie_out{$_}  }

  # Print header with cookie
  print $Query->header(-cookie=>\@cookie_lst, @hdr_opt_lst);

  if ( $str !~ m/^<!(D|d)/ ) { $str = "<!doctype html>\n" . $str } # Send a doctype html5 if none specified 
 
  print $str;

  # Save session
  $Ssn->put_ssn(\%Ssn);

  return;
}

#------------------------------------------------------------
# Streamline send
#------------------------------------------------------------
sub send_minimal
{
  my $str = shift @_;
  if ( ref $str eq 'SCALAR' ) { $str = $$str }

  # Print header with cookie
  print $Query->header(), $str;
  
  $Foot_info_flg=0;
 
  return;
}

#------------------------------------------------------------
# In case the appliction has not defined it
#------------------------------------------------------------
sub cb_show_help
{

  debug("Could not find $Query{ACTION}");

}

# ------------------------------------------------
#    Begin and End stuff
# ------------------------------------------------
BEGIN {

   $start      = (times)[0]; # Start timer
   $start_real = time ;      # Start timer

}

END {

  $stop      = (times)[0]; # Stop timer
  $stop_real = time ;      # Stop timer

  $diff = $stop - $start ;
  $diff_real = $stop_real - $start_real ;

  if ($Foot_info_flg)
  {
    print  "<font size=1><center>$diff / $diff_real cpu / real seconds</center></font>"  ;
    print  "<font size=1><center>Version $Version</font>\n"  ;
  }

  # Remove session hash from name space (in case we are using mod_perl)
  foreach $obj ( values %Sessions )
  {
     my $name   = $obj->get_attr('name');
     undef %{$name};
  }

  # Debug stuff and yet allow cookies to work . . .
  if (%Error){   debug(\%Error) }
}

1;
