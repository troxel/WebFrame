#------------------------------------------------------------
# Session Class
#
# Note: this package requires the calling of WebFrame first!
# It _requires_ the use of the following main global variables
# which are exported from WebFrame:
#
#  Cookie_in  - A hash of set cookies coming in to the application
#  Cookie_out - A hash of cookies to set in the header
#  Query      - A CGI object (this may be replaced with local code later)
#
# While this might not be pristine clean I can find no way due
# the coupling of the http header information which has to be
# handled in WebFrame.
#
#------------------------------------------------------------

package WebFrame::Ssn;

use Exporter ();
use WebFrame::Debug ;
use WebFrame::Sys ;

require Storable;
import Storable qw(retrieve store);

@ISA    = qw( WebFrame::Sys WebFrame::Debug Exporter );
@EXPORT_OK = qw( get_ssn put_ssn get_attr );

sub new
{
  my $class = shift @_;
  my %arg   = @_;

  my $self = bless
  {
    'name'      => $arg{'name'}      || croak("Missing Session Name"),
    'dir'       => $arg{'dir'}       || '/tmp/.ssn',
    'expires'   => $arg{'expires'},
    'buff_win'  => $arg{'buff_win'}  || 200,
    'buff_size' => $arg{'buff_size'} || 250
  }, $class;

  unless (-e $self->{'dir'} )  { mkdir $self->{'dir'}, 0700; }

  $self->{'ssn_id'} = $WebFrame::Cookie_in{$self->{'name'}};

  # remove this line once it is found out how the ssn_id becomes a hash ref
  if ( ref $self->{'ssn_id'} =~ /HASH/ )  { debug("ssn_id is hash ref again!"), exit; }

  # If session is not in store create a new session
  my $fspec = "$self->{'dir'}/$self->{ssn_id}";
  unless ( -f $fspec )
  {
     $self->_gen_ssn();
     $self->_set_cookie();
     $self->_trim_ssn();
  }

  return $self;
}


# - - - - - - - - - - - - - - -
sub get_ssn
{
  my $self   = shift @_;

  my $fspec = "$self->{'dir'}/$self->{ssn_id}";

  my $hsh_ref;
  if ( -f $fspec ) { $hsh_ref = retrieve($fspec) }
  else             { $hsh_ref = {}               }

  # For debugging store a copy of the the session object in the store
  # Note: this make SSN_REF a reserved token
  $hsh_ref->{'SSN_REF'} = $self;

  if ( wantarray ) { return %{$hsh_ref} }
  else             { return $hsh_ref    }
}

# - - - - - - - - - - - - - - -
sub get_attr
{
  return $_[0]->{"$_[1]"};
}

# - - - - - - - - - - - - - - -
sub put_ssn
{
  my $self    = shift @_;
  my $hsh_ref = shift @_;

  $fspec = "$self->{'dir'}/$self->{'ssn_id'}";

  # Remove the merge "feature".  It seems that merge is not what would
  # normally be expected.  For example "delete $Ssn{some_key}" would not
  # work.  I may be wrong and hence the comment...
  #if ( -f $fspec )
  #{
  #   my $disk_hsh_ref = retrieve($fspec);
  #   $hsh_ref = { %{$disk_hsh_ref}, %{$hsh_ref} }
  #}
  my $mask = umask(077);
  store($hsh_ref, $fspec);
  umask($mask);
}

# - - - - - - - - - - - - - - -
sub rmv_ssn
{
  my $self    = shift @_;

  $WebFrame::Cookie_out{$self->{'name'}} = $WebFrame::Query->cookie(-name=>"$self->{name}",-value=>"",-expires=>'now');

  $fspec = "$self->{'dir'}/$self->{'ssn_id'}";
  unlink $fspec;
}

#---- local functions ----------------------
sub _gen_ssn
{
  my $self = shift @_;

  # Generate a unique id.
  my $time = time;
  my $rnd  = int rand(10000000);
  my $name = $self->{'name'};

  $self->{'ssn_id'} = "$name.$time.$rnd";

}


sub _trim_ssn
{
  my $self = shift @_;

  my $name = $self->{'name'};
  my $dir = $self->{'dir'};

  my @lst = ls($dir,"^$name\.");

  # Maintain a specified number of viable sessions.
  if (scalar @lst > $self->{'buff_size'})
  {
     @lst = sort @lst;
     @lst = @lst[0 .. $self->{'buff_win'}];
     @lst = map {"$dir/$_"} @lst;

     unlink @lst;
  }

}

sub _set_cookie
{
  my $self = shift @_;

  $WebFrame::Cookie_out{$self->{'name'}} = $WebFrame::Query->cookie(-name=>"$self->{name}",-value=>"$self->{ssn_id}",-expires=>"$self->{'expires'}");
}

$positive_note = 1;
