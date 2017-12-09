#----------------------------------------------------------
# Realm Configuration manager
#-----------------------------------------------------------

package WebFrame::RealmSql;

require Exporter;

our @ISA = ('Exporter', 'WebFrame::RealmConf');

# Include our friends
use WebFrame::Sys;
use WebFrame::Save;
use WebFrame::Debug;
use WebFrame::Enode;
use WebFrame::User;
use WebFrame::Db_util;

use CGI::Carp qw(fatalsToBrowser);

# --- Constructor ----------------------
sub new
{
  my $caller = shift @_;

  # In case someone wants to sub-class
  my $caller_is_obj  = ref($caller);
  my $class = $caller_is_obj || $caller;

  # Passing reference or hash
  my %arg;
  if ( ref($_[0]) eq "HASH" ) { %arg = %{ shift @_ } }
  else                        { %arg = @_ }

  # enode object
  $enode_obj  = new WebFrame::Enode(\%arg);

  my $realm_name = $arg{'realm_name'} || $enode_obj->get_realm();

  my $conf_obj = new WebFrame::RealmConf();

  my %realm_info = %{ $conf_obj->{'realm_conf'}->{"$realm_name"} };

  unless ( $realm_info{'ssn_dir'} ) { $realm_info{'ssn_dir'} = "/tmp/.ssn"; }
  #{
  #   $realm_info{'ssn_dir'} = "/tmp/$realm_name/.ssn";
  #   if ( ! -d "/tmp/$realm_name/.ssn" )
  #   {
  #      unless ( -d "/tmp/$realm_name" ) { mkdir "/tmp/$realm_name" }
  #      mkdir "/tmp/$realm_name/.ssn";
  #   }
  #}

  my $ssn_obj = new WebFrame::Ssn('dir'=>$realm_info{'ssn_dir'}, 'name'=>'ticket');

  $dbh = $conf_obj->get_sql_dbh("$realm_name");

  my $userdb_obj =  new WebFrame::User( 'dbh'=>$dbh );

  my $self = bless {
                     'enode_obj'   => $enode_obj,
                     'userdb_obj'  => $userdb_obj,
                     'conf_obj'    => $conf_obj,
                     'realm_info'  => { %realm_info },
                     'realm_name'  => $realm_name,
                     'ssn_obj'     => $ssn_obj,
                     'dbh'         => $dbh,
                   }, $class;

  return $self;
}

# - - - - - - - - - - - - - - - - - - - -
# Retrieve the realm information.  Default to the
# current object hash if no realm id is provided.
# - - - - - - - - - - - - - - - - - - - -
sub get_realm_info
{
  my $self   = shift;
  my $realm_name  = shift;

  my $realm_ref;
  if ($realm_name)
  {
    $realm_ref = $self->{'conf_obj'}->get_realm_info($realm_name);
  }
  else
  {
    $realm_ref = $self->{'realm_info'};
  }

  if ( wantarray ) { return %{$realm_ref } }
  return $realm_ref;
}

# - - - - - - - - - - - - - - - - - - - -
sub get_default_grp
{
  my $self = shift;
  return $self->{'realm_info'}->{'default_grp'};
}

# - - - - - - - - - - - - - - - - - - - -
# Get realm name
# - - - - - - - - - - - - - - - - - - - -
sub get_realm_name
{
  my $self = shift;

  return $self->{'realm_name'};
}

# - - - - - - - - - - - - - - - - - - - -
sub get_grps
{
  my $self   = shift;
  my $usr_id = shift;

  my $sql = "Select DISTINCT(user_group) from user_group";
  if ( $usr_id ) { $sql .=  " where usr_id = \"$usr_id\""; }
  $sql .= " ORDER BY user_group";

  my $grp_lst = $self->{dbh}->selectcol_arrayref($sql);

  if ( wantarray ) { return  @{$grp_lst} }
  else             { return  $grp_lst    }
}

# - - - - - - - - - - - - - - - - - - - -
# Set this object realm
# - - - - - - - - - - - - - - - - - - - -
sub set_realm_info
{
  my $self = shift;
  my $ref  = shift;
  my $realm_name  = shift || $self->{'realm_name'};

  return $self->{'conf_obj'}->set_realm_info($ref, $self->{'realm_name'});
}

# - - - - - - - - - - - - - - - - - - - -
sub set_grps_for_usr
{
  my $self    = shift;
  my $usr_id  = shift;
  my $grps    = shift @_;

  my $sql = "delete from user_group where usr_id = \"$usr_id\"";
  $self->{dbh}->prepx($sql);

  foreach my $grp (@{$grps})
  {
     my $sql = "INSERT INTO user_group (user_group,usr_id) VALUES (\"$grp\",\"$usr_id\")";
     $self->{dbh}->prepx($sql);
  }

  return 1;
}


# - - - - - - - - - - - - - - - - - - - -
sub set_grp_for_usrs
{
  my $self       = shift;
  my $grp_id_in  = shift;
  my @usr_lst    = @{ shift @_ };

  # Note: if no @usr_lst is provided then this group is removed.

  # do some validation
  unless ($grp_id_in)        { error_page "need to define a grp_id"; exit; }

  my $sql = "delete from user_group where user_group = \"$grp_id_in\"";
  $self->{dbh}->prepx($sql);

  foreach my $usr (@usr_lst)
  {
     my $sql = "INSERT INTO user_group (user_group,usr_id) VALUES (\"$grp_id_in\",\"$usr\")";
     $self->{'dbh'}->prepx($sql);
  }

  return 1;
}

# - - - - - - - - - - - - - - - - - - - -
# Get a list of users for realm
#
# If no grp_id is provided all users are
# returned.  A single or multiple (list) of
# groups may be provided as input to restrict
# the list to the group set.
# - - - - - - - - - - - - - - - - - - - -
sub get_usrs
{
  my $self      = shift;
  my @grp_id_in = @_;

  my $sql = "SELECT DISTINCT(usr_id) from user_group";

  if ( @grp_id_in )
  {
     my @or;
     foreach my $grp ( @grp_id_in )
     {
       push @or, "user_group = \"$grp\"";
     }

     $sql .= " WHERE " . join " OR ", @or;
  }

  $sql .= " ORDER BY usr_id";

  my $lst = $self->{dbh}->selectcol_arrayref($sql);

  if ( wantarray ) { return @{$lst} }
  else             { return $lst    }
}

# - - - - - - - - - - - - - - - - - - - -
sub get_usr_lvl
{
  my $self   = shift;
  my $usr_id = shift;

  # Get application positional grps and access levels
  my %grp2lvl = $self->{'enode_obj'}->get_grps();


  # Get the list of grps for this usr
  my @grp_lst = $self->get_grps($usr_id);

  # Find max lvl
  my ($max_lvl, $max_grp);
  foreach my $usr_grp ( @grp_lst )
  {
     if ( $grp2lvl{$usr_grp} > $max_lvl )
     {
        $max_lvl = $grp2lvl{$usr_grp};
        $max_grp = $usr_grp;
     }
  }

  return ($max_lvl,$max_grp);
}


# - - - - - - - - - - - - - - - - - - - -
# Auth Functions
# - - - - - - - - - - - - - - - - - - - -

sub auth
{
  my $self    = shift @_;
  my $timeout = shift @_;
  unless ( $timeout ) { $timeout = 7200 }

  # -------------------
  # Check Auth Tokens if ticket based authentication is in play
  # -------------------
  $ENV{'REMOTE_USER'} = $ENV{'REMOTE_USER'} || $ENV{'REDIRECT_REMOTE_USER'};

  # -------------------
  # Expermental code - to allow for crontab running of callbacks/skipping authentication
  # -------------------
  if ( $ENV{'REMOTE_ADDR'} eq $ENV{'SERVER_ADDR'}  )
  {
     $ENV{'REMOTE_USER'} = 'local_user';   # local_user is now a reserved key word...
  }

  unless ( $ENV{'REMOTE_USER'} )
  {
      my $ticket = $WebFrame::Cookie_in{'ticket'};

      unless ( $ticket ) { _challenge( $self->{'realm_info'}->{'challenge_url'} ) }  # no ticky no laundry (no return from challenge)

      # Retrieve the auth session
      my %ssn = $self->{'ssn_obj'}->get_ssn();

      # Auth session must exist and contain specific parameters
      unless ( $ssn{'time_prev'} && $ssn{'REMOTE_USER'} && $ssn{'REMOTE_ADDR'} )
      {
         _challenge( $self->{'realm_info'}->{'challenge_url'} , 'No Login Session Found' )
      }

      # Now Check for a timeout condition
      my $time_prev = $ssn{'time_prev'};
      my $time = time;
      if ( ($time_prev + $timeout ) < $time)
      {
         _challenge( $self->{'realm_info'}->{'challenge_url'} , 'Session has Expired' );  # no return
      }

      # IP check
      #unless ( $ENV{'REMOTE_ADDR'} eq $auth_ssn{'REMOTE_ADDR'}  ) { _challenge( $realm_obj->get('challenge_url'),"IP changed from $auth_ssn{'REMOTE_ADDR'} to $ENV{'REMOTE_ADDR'}" ) } # IP should not change (no return)

      # Intitially things look good for this request
      $ssn{'time_prev'} = time;
      $ssn{'REMOTE_ADDR'} = $ENV{'REMOTE_ADDR'}; # For ip check

      $self->{'ssn_obj'}->put_ssn(\%ssn);

      # Set remote user environment
      $ENV{'REMOTE_USER'} = $ssn{'REMOTE_USER'};   # Looks just like basic authentication
      $ENV{'AUTH_TYPE'}   = 'TICKET';                   # Differentation
  }

  # -------------------
  # Get User Group Information
  # -------------------
  my ($max_lvl,$max_grp) = $self->get_usr_lvl($ENV{'REMOTE_USER'});

  # Experimental code. This is the beginning of wnode which will replace enode.
  # Add new directive to all access if not group permissions but user is authenticated.
  unless ( $max_lvl )
  {
     my $wnode = safe_read("$main::Dir{src}/.wnode") if -r "$main::Dir{src}/.wnode";
     if ( $wnode->{'bypass_grp'} ) { $max_lvl = 10 }
  }

  unless ( $max_lvl ) {  _deny() }  # Must be in a group to proceed - no return

  # ---------------------------------------
  # If we made it here we are authenticated
  # ---------------------------------------

  # get user information
  my %usr_info = $self->{'userdb_obj'}->get_usr_info( $ENV{'REMOTE_USER'} );

  # append group information
  $usr_info{'max_lvl'} = $max_lvl;
  $usr_info{'max_grp'} = $max_grp;

  # This does not belong here (reorg is pending).
  # As of right now ddt is the only app using this
  my %grp2lvl = $self->{'enode_obj'}->get_grps();
  $usr_info{'grp2lvl'}    = { %grp2lvl };

  # For convience and display purposes add the realm
  $usr_info{'realm_name'} = $self->{'realm_name'};

  if (wantarray) { return %usr_info  }
  else           { return \%usr_info }
}

# - - - - - - - - - - - - - - - - - - - - -
sub unauth
{
  my $self = shift @_;
  my $user = shift @_;

  my %ssn = $self->{'ssn_obj'}->get_ssn();

  $ssn{'time_prev'}   = 0;
  $ssn{'REMOTE_ADDR'} = "";
  $ssn{'REMOTE_USER'} = "";

  return $self->{'ssn_obj'}->put_ssn(\%ssn);
}


# - - - - - - - - - - - - - - - - - - - - -
sub match_passwd
{
  my $self = shift @_;
  my $user  = shift @_;
  my $passwd_query = shift @_;

  # Get passwd on record
  my $passwd_file = get_htpasswd($self,$user);

  my $passwd_query = _passwd_enc($passwd_query,$passwd_file);

  # Debug lines
  #$WebFrame::Error{passwd_query} = $passwd_query;
  #$WebFrame::Error{passwd_file}  = $passwd_file;

  if ( $passwd_query eq $passwd_file ) { return $passwd_query;  }   # yay
  return 0;                                                         # nay
}

# - - - - - - - - - - - - - - - - - - - - -
sub set_auth_ssn
{
  my $self = shift @_;
  my $usr  = shift @_;

  # Must of matched password in login now create a realm session
  my %ssn = $self->{'ssn_obj'}->get_ssn();

  $ssn{'time_prev'}   = time;                # For login session ageing
  $ssn{'REMOTE_ADDR'} = $ENV{'REMOTE_ADDR'}; # For ip check
  $ssn{'REMOTE_USER'} = $usr;                # For retrieving user information

  return $self->{'ssn_obj'}->put_ssn(\%ssn);
}

# - - - - - - - - - - - - - - - - - - - - -
# Private Functions
# - - - - - - - - - - - - - - - - - - - - -

sub _passwd_enc
{
  my $passwd_txt = shift;
  my $salt       = shift ;

  unless ($salt) { $salt = join '', (0..9,'A'..'Z','a'..'z')[rand 61, rand 61] }
  my $passwd_enc = crypt($passwd_txt,$salt);

  return $passwd_enc;
}


# - - - - - - - - - - - - - - - - - - - -
sub _challenge
{
  my $challenge_url = shift;
  my $reason = shift;

  unless ( $challenge_url ) { $challenge_url = '/login/' }       # default

  my $referer = $ENV{'REQUEST_URI'};

  # url encode for the round trip
  $referer =~ s/([^\w-])/sprintf("%%%02X",ord($1))/eg;

  print "Status: 302 Moved\n";
  print "Location: $challenge_url?referer=$referer&msg=$reason\n\n";

  exit;
}

sub _deny
{
  error_page("$ENV{REMOTE_USER} does not have sufficient group access permissions","To Request Access Contact $ENV{'SERVER_ADMIN'}");
  exit;
}


# - - - - - - - - - - - - - - - - - - - -
# htpasswd functions
# - - - - - - - - - - - - - - - - - - - -


# - - - - - - - - - - - - - - - - - - - -
sub set_htpasswd
{
   my $self     = shift;
   my $usr_id   = shift;
   my $passwd   = shift; # must be the enc passwd

   # If no password is provided then the user is removed from the htpasswd file.

   unless ( $usr_id)  { error_page("No usr_id provided"); exit;       }

   my $fspec = $self->{'realm_info'}->{'AuthUserFile'};

   unless (-e $fspec) { return 0 }

   my @in = read_file($fspec);

   my @out;
   foreach $line (@in)
   {
     ( $usr_id_line,$passwd_line ) = split /\s*:\s*/, $line;

     if ( $usr_id_line eq $usr_id ) { next }                 # Remove from list if exist
     push @out, $line;
   }

   if ($passwd) { push @out, "$usr_id:$passwd\n" }             # Add back to list if password provided

   @out = sort { lc($a) cmp lc($b) } @out;

   return write_file($fspec,\@out);
}

# - - - - - - - - - - - - - - - - - - - -
sub get_htpasswd
{
   my $self     = shift;
   my $usr_id   = shift;

   my $fspec = $self->{'realm_info'}->{'AuthUserFile'};

   unless (-e $fspec) { error_page("Cannot find $fspec"); exit; }

   my @in = read_file($fspec);

   my @out;
   foreach $line (@in)
   {
     chomp $line;
     ( $usr_id_line,$passwd_line ) = split /\s*:\s*/, $line;
     if ( $usr_id_line eq $usr_id ) { return $passwd_line }
   }

   return 0;
}


# - - - - - - - - - - - - - - - - - - - -
sub rmv_htpasswd
{
   my $self   = shift;
   my $usr_id = shift;
   my $force  = shift; # Optional flag for forcing a remove for htpasswd

   unless ( $usr_id)  { error_page("No usr_id provided"); exit; }

   if ( $force ) { return $self->set_htpasswd($usr_id) } # empty set effects a remove passwd

   # Unless the $force_flg is this function only removes the supplied
   # user from the htpasswd file if they are only active in the present
   # realm.  If the user is in an active member in another realm then they remain.

   my $auth_fspec = $self->{'realm_info'}->{'AuthUserFile'};

   my @realm_lst = $self->{'conf_obj'}->get_realm_lst();

   foreach my $realm_name ( @realm_lst )
   {
      my $realm_obj = new WebFrame::Realm('realm_name'=>"$realm_name");

      # Do not check the current realm
      if ( $realm_name eq $self->{'realm_name'} ) { next }

      # Check for the same htpasswd file
      if ( $auth_fspec eq $self->{'realm_info'}->{'AuthUserFile'} )
      {
         my @lst = $realm_obj->get_grps($usr_id);
         if ( scalar @lst ) { return 0 }
      }
   }

   return $self->set_htpasswd($usr_id);
}

# ---------------
# Insert Nonce
# Insert is a misnomer as this function now does an update due to combining
# the webuser database tables; 
# Added check to be sure the user record is already inserted.
# ---------------
sub insert_nonce
{
   my $self = shift @_;
   my $usr_id = shift @_;

   my $nonce = gen_nonce();

   # user name must be unique so use nonce - it will be replace on registration...
   #my $sql = "INSERT into user_store (usr_id,nonce,time_cac_mod) values (\"$usr_id\",\"$nonce\",now())";
   #
   
   my $rtn_rec = $self->get_usr_info($usr_id);
   
   unless ( $rtn_rec )
   {
      debug("User Record for $usr_id Not Found"); exit;   
   }
   
   # Now with combined table user_store this is an update and not a insert
   my $sql = "UPDATE user_store set nonce = \"$nonce\",time_cac_mod = now(),user_DN=\"\" where usr_id = \"$usr_id\"";
   $self->{dbh}->prepx($sql) || die "Cannot update into table";

   return $nonce;
}

# ---------------
# gen unique string
# ---------------
sub gen_nonce
{
  my $nonce;
  foreach (1..32)
  {
    $char = chr(int(rand(26)) + 97);
    if ( int rand(2) ) { $char = uc($char) }
    $nonce .= $char;
  }
  return $nonce;
}



# - - - - - - - - - - - - - - - - - - - -
sub get_ip_lst
{
   my $self = shift;

   my $fspec = $self->{'realm_info'}->{'ip_lst'};

   my @lst = ();
   if (-e $fspec) { @lst = read_file($fspec) }

   return @lst;
}

# - - - - - - - - - - - - - - - - - - - -
sub set_ip_lst
{
   my $self = shift;
   my @lst  = @_;

   my $fspec = $self->{'realm_info'}->{'ip_lst'};

   return write_file( $fspec, @lst );
}


# - - - - - - - - - - - - - - - - - - - -
sub get_time
{
   my $self = shift;

   my $time = time;

   if ( $self->{'realm_info'}->{'time_offset'} )
   {
     $time += $self->{'realm_info'}->{'time_offset'} * 3600;
   }
   return $time;
}

# - - - - - - - - - - - - - - - - - - - -
sub get
{
   my $self      = shift;
   my $attribute = shift;

   return $self->{'realm_info'}->{$attribute};
}

# - - - - - - - - - - - - - - - - - - - -
# RealmConf Connector Functions
# - - - - - - - - - - - - - - - - - - - -
sub get_realm_lst
{
   my $self      = shift;
   return $self->{'conf_obj'}->get_realm_lst();
}

# - - - - - - - - - - - - - - - - - - - -
# User_db Connector Functions
# - - - - - - - - - - - - - - - - - - - -
sub get_usr_lst
{
   my $self      = shift;
   return $self->{'userdb_obj'}->get_usr_lst(@_);
}

sub set_usr_info
{
   my $self      = shift;
   return $self->{'userdb_obj'}->set_usr_info(@_);
}

sub get_usr_info
{
   my $self      = shift;
   return $self->{'userdb_obj'}->get_usr_info(@_);
}

sub get_usr_pki
{
   my $self      = shift;
   return $self->{'userdb_obj'}->get_usr_pki(@_);
}

sub rmv_usr_pki
{
   my $self      = shift;
   return $self->{'userdb_obj'}->rmv_usr_pki(@_);
}

sub rmv_usr_nonce
{
   my $self      = shift;
   return $self->{'userdb_obj'}->rmv_usr_nonce(@_);
}

sub get_usr_reg_lst
{
   my $self      = shift;
   return $self->{'userdb_obj'}->get_usr_reg_lst(@_);
}

sub get_usr_inv_lst
{
   my $self      = shift;
   return $self->{'userdb_obj'}->get_usr_inv_lst(@_);
}

sub get_usr_na_lst
{
   my $self      = shift;
   return $self->{'userdb_obj'}->get_usr_na_lst(@_);
}

sub get_usr_nin
{
   my $self      = shift;
   return $self->{'userdb_obj'}->get_usr_nin(@_);
}

# - - - - - - - - - - - - - - - - - - - -
# Private Functions
# - - - - - - - - - - - - - - - - - - - -


#-----------------------------------------------------------
# Realm Configuration manager
#-----------------------------------------------------------

package WebFrame::RealmConf;

require Exporter;

our @ISA = 'Exporter';

# Include our friends
use WebFrame::Debug;
use WebFrame::Sys;

# --------------------------
# Class Data and methods
{
  my %default;

  # The ENV var is set via
  # SetEnv realm_conf "dir_path"
  # in .htaccess or http.conf
  if ( $ENV{'REDIRECT_realm_conf'} ) { $default{'fspec'} = "$ENV{'REDIRECT_realm_conf'}/realm.conf" }
  else                               { $default{'fspec'} = "/var/www/realm.conf"                    }

  # Class methods
  sub set_defaults
  {
    my $class = shift @_;

    my %set;
    if (  ref($_[0]) eq "HASH" ) { %set = %{ $_[0] } }
    else                         { %set = @_         }

    # Merge with existing hash
    %default = ( %default, %set);

    return %default;
  }

  sub get_defaults
  {
    return %default;
  }
}

# --- Constructor ----------------------
sub new
{
  my $caller = shift @_;

  # In case someone wants to sub-class
  my $caller_is_obj  = ref($caller);
  my $class = $caller_is_obj || $caller;

  # Passing reference or hash
  my %arg;
  if ( ref($_[0]) eq "HASH" ) { %arg = %{ shift @_ } }
  else                        { %arg = @_ }

  # Override default hash with arguments
  my %obj_conf = __PACKAGE__->get_defaults();
  %obj_conf = (%obj_conf, %arg);

  # verify input
  unless ( -e $obj_conf{'fspec'} ) { die("Cannot find realm configuration file $obj_conf{'fspec'}") }

  my $realm_conf_ref = safe_read($obj_conf{'fspec'});

  # The object data structure
  my $self = bless
  {
               'realm_conf' => $realm_conf_ref,
               'obj_conf'   => {%obj_conf},
   }, $class;

  return $self;
}

# - - - - - - - - - - - - - - - - - - - -
sub get_realm_lst
{
  my $self   = shift;

  my $hsh_ref = $self->{realm_conf};

  my @lst = keys %{ $hsh_ref };

  if ( wantarray ) { return @lst }
  return           { [@lst]      }
}

# - - - - - - - - - - - - - - - - - - - -
sub get_realm_info
{
  my $self       = shift;
  my $realm_name = shift;

  my $hsh_ref = $self->{realm_conf}->{$realm_name};

  if ( wantarray ) { return %{$hsh_ref} }
  return           { $hsh_ref     }
}

# - - - - - - - - - - - - - - - - - - - -
# Set the realm information.
# - - - - - - - - - - - - - - - - - - - -
sub set_realm_info
{
  my $self    = shift;
  my $hsh_ref = shift;
  my $realm_name = shift;

  unless ( ref($hsh_ref) =~ /HASH/ ) { error_page "Wrong Arguement Type!, First arguement must be hash reference" ; exit; }

  unless ( $realm_name ) { debug "Must supply realm name"; exit; }

  my $fspec = $self->{'obj_conf'}->{'fspec'};

  # read in realm again to ensure concurrancy
  my $realm_conf_ref = safe_read($fspec) || die "Cannot read realm configuration $fspec";

  # Delete realm record if it is empty save the realm_name
  if (scalar keys %{$hsh_ref} == 1 ) { delete $realm_ref->{$realm_name}     }
  else                               { $realm_conf_ref->{$realm_name} = $hsh_ref }

  require Data::Dumper;
  import Data::Dumper 'Dumper';

  $Data::Dumper::Terse = 1;
  my $str = Dumper($realm_conf_ref);

  return write_file($fspec,$str);
}

# - - - - - - - - - - - - - - - - - - - -
# Set the realm information.
# - - - - - - - - - - - - - - - - - - - -
sub get_sql_dbh
{
  my $self       = shift;
  my $realm_name = shift;

  my $dsn_id = $self->{realm_conf}->{$realm_name}->{'usrdb_dsn'};

  #my $conf = $self->{realm_conf}->{'RSV_AUTH_SQL'}->{$dsn_id}; # what is RSV_AUTH_SQL? don't know... 
  my $conf = $self->{realm_conf}->{$realm_name};

  $conf->{'DSN'} = "dbi:mysql:host=localhost;database=$conf->{'DB'}";
  $conf->{'USR'} = $conf->{'User'};
  $conf->{'PSD'} = $conf->{'Password'};

  my $dbh = WebFrame::Db_util->new( $conf );

  return $dbh;
}



1;
