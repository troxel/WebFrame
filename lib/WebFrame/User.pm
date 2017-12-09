#-----------------------------------------------------------
package WebFrame::User;

use Exporter ();

use WebFrame::Save;
use WebFrame::Debug;
use WebFrame::Db_util;
use WebFrame::Sys;

@ISA = qw( WebFrame::Sys WebFrame::Save Exporter );
@EXPORT = qw( );

# Mod May 2017 
# Combined user_info and user_data into one table -> user_store


# --------------------------
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

  # verify input
  #unless ( ( $arg_hsh{'dir'} ) || ( $arg_hsh{'dbn'} ) ) { warn("Must specify a user directory OR dbn") }

  # The object data structure
  my $self = bless {
                        'usr_lst'   => [],
                        'dbh'       => $arg_hsh{'dbh'},
                   }, $class;

  return $self;
}

#----------------------------------------------------------------------
sub get_usr_info {

 my $self   = shift;
 my $usr_id = shift;

 my $user = $self->{dbh}->selectrow_hashref("SELECT * from user_store where usr_id = \"$usr_id\"");

 if (wantarray) { return %{$user} }
 else           { return($user)   };
}

#--------------------------------------------------------
sub set_usr_info {

 my $self    = shift;
 my $hsh_ref = shift;

 unless ( ref $hsh_ref eq "HASH") { debug("Expecting a Hash Ref"); return 0; }
 unless ( $hsh_ref->{'usr_id'}  ) { debug("No User Id Specified"); return 0; }

 my $sql = "SELECT \* FROM user_store WHERE usr_id = \"$hsh_ref->{'usr_id'}\"";
 my $usr_ref = $self->{dbh}->selectrow_hashref($sql);

 if ( $usr_ref )
 {
   $self->{dbh}->update_row('user_store',$hsh_ref,'usr_id');
 }
 else
 {
   $self->{dbh}->insert_row('user_store',$hsh_ref);
 }
}

#---------------------------------------
# Registered Users
sub get_usr_reg_lst
{
   my $self    = shift;

   # CN (common name) is in the users name for all users
   my $lst = $self->{'dbh'}->selectcol_arrayref("SELECT usr_id from user_store where user_DN !=\"\"");

   if (wantarray) { return @{$lst} }
   else           { return $lst    };
}
#---------------------------------------
# Invited Users
sub get_usr_inv_lst
{
   my $self    = shift;

   my $lst = $self->{'dbh'}->selectcol_arrayref("SELECT usr_id from user_store where nonce IS NOT NULL");

   if (wantarray) { return @{$lst} }
   else           { return $lst    };
}
#---------------------------------------
# Not Active Users
sub get_usr_na_lst
{
   my $self    = shift;

   #my $lst = $self->{'dbh'}->selectcol_arrayref("SELECT usr_id FROM user_data WHERE usr_id NOT IN (SELECT usr_id FROM user_info)");
   my $lst = $self->{'dbh'}->selectcol_arrayref("SELECT usr_id FROM user_store WHERE user_DN =\"\"");
   
   if (wantarray) { return @{$lst} }
   else           { return $lst    };
}

#--------------------------------
# All Users
sub get_usr_lst
{
   my $self    = shift;

   my $lst = $self->{'dbh'}->selectcol_arrayref("SELECT usr_id from user_store");

   if (wantarray) { return @{$lst} }
   else           { return $lst    };
}

#--------------------------------
# Test for users not in user tble but in grp tbl
# This is not suppose to happen warn manager.
sub get_usr_nin
{
  my $self   = shift;
  my $grp_id = shift @_;

  my $sql   = "SELECT * from user_group WHERE usr_id NOT IN (SELECT usr_id FROM user_store) AND user_group = \"$grp_id\"";
  my $lst = $self->{dbh}->selectcol_arrayref($sql);

  if ( wantarray ) { return @{$lst} }
  else             { return $lst    }
}


#-------------------------------
sub get_usr_pki
{
   my $self = shift;
   my $usr_id = shift;

   my $sql = "SELECT * FROM user_store WHERE usr_id = \"$usr_id\"";
   my $loh_ref = $self->{dbh}->selectall_arrayref($sql,{'Columns'=>{}});

   return $loh_ref;
}

sub rmv_usr_pki
{
   my $self = shift;
   my $pki = shift;

   my $sql = "UPDATE user_store set user_DN = \"\" WHERE user_DN = \"$pki\"";
   $self->{dbh}->prepx($sql);

   return 1;
}

sub rmv_usr_nonce
{
   my $self = shift;
   my $nonce = shift;

   my $sql = "UPDATE user_store set nonce = NULL WHERE nonce = \"$nonce\"";
   $self->{dbh}->prepx($sql);

   return 1;
}

1;
