#-----------------------------------------------------------
package WebFrame::UserDb;

use Exporter ();

use WebFrame::Save;
use WebFrame::Debug;
use WebFrame::Sys;

@ISA = qw( WebFrame::Sys WebFrame::Save Exporter );
@EXPORT = qw( );

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
                        'dir'       => $arg_hsh{'dir'} || "/var/www/info",
                        'dbn'       => $arg_hsh{'dbn'},
                   }, $class;

  return $self;
}

#----------------------------------------------------------------------
sub get_usr_info {

 my $self   = shift;
 my $usr_id = shift;

 my $file = $self->{dir} . "/$usr_id/info.db";

 unless ( -e $file ) { return }

 my %info = parse_read("$file");

 if (wantarray) { return %info  }
 else           { return({%info}) };
}

#----------------------------------------------------------------------
sub set_usr_info {

 my $self    = shift;
 my $hsh_ref = shift;

 unless ( ref $hsh_ref eq "HASH") { debug("Expecting a Hash Ref"); return 0; }
 unless ( scalar %{$hsh_ref}    ) { debug("Zero size hash");       return 0; }
 unless ( $hsh_ref->{'usr_id'}  ) { debug("No User Id Specified"); return 0; }

 # Just a fuzzy check
 unless ( scalar %{$hsh_ref} > 4 ) { debug("hash reference too small"); return 0;}


 # Do not store any unecrypted passwd's
 foreach my $k ( keys %{$hsh_ref} )
 {
   if ($k =~ /^passwd_txt.*/) { delete $hsh_ref->{$k} }
 }

 my $usr_id = $hsh_ref->{'usr_id'};

 my $dir = $self->{'dir'} . "/$usr_id";

 unless (-e $dir) { mkdir $dir, 0700 }

 my $file = "$dir/info.db";

 rotate_files($file,2);

 if ( parse_save("$file",$hsh_ref) ) { return 1 }
 else                                { return 1 }

}

sub get_usr_lst
{
   my @lst = ( sort { lc($a) cmp lc($b) } &ls( @_[0]->{'dir'} ) );

   if (wantarray) { return @lst    }
   else           { return([@lst]) };
}

1;
