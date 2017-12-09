#-----------------------------------------------------------
# Athentication
#-----------------------------------------------------------

package WebFrame::Auth;

# $Id: Auth.pm,v 1.2 2004/04/20 17:46:40 troxelso Exp $

use Exporter;

our @ISA = qw(Exporter);

@EXPORT = ( 'auth' );
@EXPORT_OK = qw( find_realm find_enode find_file );

# Include our friends
use WebFrame::Sys  ;
use WebFrame::Save ;
use WebFrame::Ssn;
use WebFrame::Debug;

use WebFrame::Realm;
use WebFrame::UserDb;


my %enode      = find_enode();


sub new
{

  my $caller = shift @_;

  # In case someone wants to sub-class
  my $caller_is_obj  = ref($caller);
  my $class = $caller_is_obj || $caller;

  # Passing reference or hash
  my %arg_hsh;
  if ( ref($_[0]) eq "HASH" ) { %arg_hsh = %{ shift @_ } }
  else                        { %arg_hsh = @_ }

  # realm object
  my $realm_name = find_realm();
  my $realm_obj  = new WebFrame::Realm('realm'=>$realm_name);

  my %realm_info = $realm_obj->get_realm_info();

  unless ( $realm_info{'ssn_dir'} ) { debug( "No Ssn Directory Defined in realm configuration : $realm_name");exit; }
  my $auth_ssn_obj = new WebFrame::Ssn('dir'=>$realm_info{'ssn_dir'}, 'name'=>'ticket');

  my $self = bless {
                     'realm_obj'    => $realm_obj,
                     'auth_ssn_obj' => $auth_ssn_obj,
                     'timeout'      => $arg_hsh{'timeout'} || 7200,
                   }, $class;

  return $self;
}

sub auth
{

  my $self = shift @_;
  # -------------------
  # Check Auth Tokens if ticket based authentication is in play
  # -------------------
  unless ( $ENV{'REMOTE_USER'} )
  {
      my $ticket = $WebFrame::Cookie_in{'ticket'};
      unless ( $ticket ) { $self->_challenge() }  # no ticky no laundry (no return from challenge)

      # Retrieve the auth session
      my %auth_ssn = $self->{'auth_ssn_obj'}->get_ssn();

      # Auth session must exist and contain specific parameters
      unless ( $auth_ssn{'time_prev'} && $auth_ssn{'REMOTE_USER'} && $auth_ssn{'REMOTE_ADDR'} )
      {
         $self->_challenge( 'No Login Session Found' )
      }

      # Now Check for a timeout condition
      my $time_prev = $auth_ssn{'time_prev'};
      my $time = time;

      if ( ($time_prev + $timeout ) < $time)
      {
         my $url = $realm_obj->get('challenge_url');
         _challenge( $url, 'Session has Expired' );  # no return
      }

      # IP check
      #unless ( $ENV{'REMOTE_ADDR'} eq $auth_ssn{'REMOTE_ADDR'}  ) { _challenge( $realm_obj->get('challenge_url'),"IP changed from $auth_ssn{'REMOTE_ADDR'} to $ENV{'REMOTE_ADDR'}" ) } # IP should not change (no return)

      # Intitially things look good for this request
      $auth_ssn{'time_prev'} = time;
      $self->{'auth_ssn_obj'}->put_ssn(\%auth_ssn);

      # Set remote user environment
      $ENV{'REMOTE_USER'} = $auth_ssn{'REMOTE_USER'};   # Looks just like basic authentication
      $ENV{'AUTH_TYPE'}   = 'TICKET';                   # Differentation
  }

  # -------------------
  # Get User Group Information
  # -------------------
  my @grp_lst = $realm_obj->get_grps($ENV{'REMOTE_USER'});

  # -------------------
  # Get application positional grp access levels
  # -------------------
  my @grp_keys = grep /grp_[\w-]+/, keys %enode;

  # grep out group keys
  my %grp2lvl;           # relates grp_id to lvl from enode position
  foreach (@grp_keys)
  {
     /grp_([\w-]+)/;
     $grp2lvl{$1} = $enode{$_};   # Set the access level
  }

  # find max lvl
  my $max_lvl;
  foreach $usr_grp ( @grp_lst )
  {
     if ( $grp2lvl{$usr_grp} > $max_lvl )
     {
        $max_lvl = $grp2lvl{$usr_grp};
        $max_grp = $usr_grp;
     }
  }

  # Special exception for application webuser.
  # The configuration should have set a default grp however...
  if ( ( (caller)[1] =~ /webuser\.pl/ ) && ($max_lvl < 10 ) ) { $max_lvl = 10  }

  unless ( $max_lvl ) {  _deny() }  # Must be in a group to proceed - no return

  # ---------------------------------------
  # If we made it here we are authenticated
  # ---------------------------------------

  # get user information
  $usr = new WebFrame::UserDb('dir'=>$realm_info{'usrdb_dir'}) ;
  my %usr_info = $usr->get_usr_info( $ENV{'REMOTE_USER'} );

  # append group information
  $usr_info{'max_lvl'} = $max_lvl;
  $usr_info{'max_grp'} = $max_grp;
  $usr_info{'grps'}    = [ @grp_lst ];

  # This does not belong here (reorg is pending).
  # As of right now ddt is the only app using this
  $usr_info{'grp2lvl'}    = { %grp2lvl };

  # For convience and display purposes add the realm
  $usr_info{'realm_name'} = $realm_info{'realm_name'};




  # The object data structure
  my $self = bless $Dbh, $class;

  return $self;






  if (wantarray) { return %usr_info  }
  else           { return \%usr_info }







}

# - - - - - - - - - - - - - - - - - - - - -
sub unauth
{
  my $user  = shift @_;

  # Must of Matched Password Now Create a Ticket
  my $ssn_auth = new WebFrame::Ssn('dir'=>$realm_info{'ssn_dir'},'name'=>"ticket");
  my %ssn_auth = $ssn_auth->get_ssn();

  $ssn_auth{'time_prev'}   = 0;
  $ssn_auth{'REMOTE_ADDR'} = "";
  $ssn_auth{'REMOTE_USER'} = "";

  return $ssn_auth->put_ssn(\%ssn_auth);
}


# - - - - - - - - - - - - - - - - - - - - -
sub match_passwd
{
  my $passwd_user  = shift @_;
  my $passwd_query = shift @_;

  # Get passwd on record
  my $usr_obj = new WebFrame::UserDb('dir'=>$realm_info{'usrdb_dir'});

  my %usr_info = $usr_obj->get_usr_info( $passwd_user );

  my $passwd_file = $usr_info{'passwd'};

  my $passwd_query = passwd_enc($passwd_query,$passwd_file);

  # Debug lines
  #$WebFrame::Error{passwd_query} = $passwd_query;
  #$WebFrame::Error{passwd_file}  = $passwd_file;

  if ( $passwd_query eq $passwd_file ) { return $passwd_query;  }   # yay
  return 0;                                                         # nay
}

sub passwd_enc
{
  my $passwd_txt = shift;
  my $salt       = shift ;

  unless ($salt) { $salt = join '', (0..9,'A'..'Z','a'..'z')[rand 61, rand 61] }
  my $passwd_enc = crypt($passwd_txt,$salt);

  return $passwd_enc;
}

# - - - - - - - - - - - - - - - - - - - - -
sub set_auth_ssn
{
  my $user  = shift @_;

  # Must of Matched Password Now Create a Ticket
  my $ssn_auth = new WebFrame::Ssn('dir'=>$realm_info{ssn_dir},'name'=>"ticket");
  my %ssn_auth = $ssn_auth->get_ssn();

  $ssn_auth{'time_prev'}   = time;                # For login session ageing
  $ssn_auth{'REMOTE_ADDR'} = $ENV{'REMOTE_ADDR'}; # For ip check
  $ssn_auth{'REMOTE_USER'} = $user;               # For retrieving user information

  return $ssn_auth->put_ssn(\%ssn_auth);
}


# - - - - - - - - - - - - - - - - - - - - -
# Private Functions
# - - - - - - - - - - - - - - - - - - - - -

# - - - - - - - - - - - - - - - - - - -
sub find_realm
{

 my @file_lst = reverse find_file('.htaccess'); # reverse so that first one wins

 my $realm;
 foreach my $fspec (@file_lst)
 {
    foreach ( read_file($fspec) )
    {
        /^AuthName\s+(.*?)\s*$/i;
        if ($1)
        {
           $realm = $1;
           $realm =~ s/"//g;
           goto found;
        }
    }

 }

 found:

 unless ($realm) { debug "no realm found"; exit; }
 return $realm;
}

# - - - - - - - - - - - - - - - - - - -
sub find_enode
{

 my @file_lst = reverse find_file('.enode');

 my %enode;
 foreach my $fspec (@file_lst)
 {
     my %hsh = parse_read($fspec);

     my ($override) = grep /allowoverride/i, keys %hsh;

     %enode = (%hsh, %enode ); # merge with priority on lower level data

     if ( $hsh{$override} =~ /none/i ) { last }  # Stop processessing
 }

 if (wantarray) { return %enode }
 else           { return {%enode} }
}

# - - - - - - - - - - - - - - - - - - -
sub find_file
{

  my $file_name = shift @_;

  my $dir_root = $main::Dir{'root'} || warn  'No dir root found!';
  my $dir_rel  = $main::Dir{'rel'}  || warn 'No dir rel  found!';

  my $sep = '/';  # unix like file systems only - for now

  my @rel_lst = split /$sep/, $dir_rel;

  my @file_lst;

  my $fspec = join "$sep", ( $dir_root, $file_name) ;
  if (-e $fspec) { push @file_lst, $fspec }

  for (my $i = 0; $i <= $#rel_lst; $i++ )
  {
    $fspec = join "$sep", ( $dir_root, @rel_lst[0..$i], $file_name) ;

    if (-e $fspec) { push @file_lst, $fspec }
  }

  return @file_lst;
}

# - - - - - - - - - - - - - - - - - - - -
sub _challenge
{
  my $self = shift;

  my $challenge_url = $self->{'realm_obj'}->get('challenge_url');

  unless ( $challenge_url ) { $challenge_url = '/login/' }       # default

  my $reason = shift;

  my $referer = $ENV{'REQUEST_URI'};

  print "Status: 302 Moved\n";
  print "Location: $challenge_url?referer=$referer&msg=$reason\n\n";

  exit;
}

sub _deny
{

  debug('You do not have sufficient access permissions');
  exit;
}
1;

