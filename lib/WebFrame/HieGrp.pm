package HieGrp;

use Exporter ();
use WebFrame::Db_util;
use WebFrame::Debug ;
use WebFrame::Sys ;

@ISA = qw( Db_util Webframe::Debug Exporter );



# - - - - - - - - - - - - - - -

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

  my ( %ord_hoh, %grp_hoh );
  if ( my $dbh = $arg_hsh{'dbh'} )
  {
      # - - - - - - - - - - - - - - - - - - - - - - - - - - -
      # Get the order/group info from standardized db tables
      my $sql = "SELECT * FROM Grp_Ord";
      %ord_hoh = %{ $dbh->selectall_hashref($sql, 'ord' ) };

      my $sql = "SELECT * FROM Grp_Info";
      %grp_hoh = %{ $dbh->selectall_hashref($sql, 'grp_id' ) };
  }
  else
  {
     # - - - - - - - - - - - - - - - - - - - - - - - - - - -
     # Get the order/group info from input
     %ord_hoh = %{ $arg_hsh{'ord_hoh'} };
     %grp_hoh = %{ $arg_hsh{'grp_hoh'} };
  }

  # verify input
  #unless ( scalar %ord_hoh ) { debug("Must specify a ord hoh"); exit }
  #unless ( scalar %grp_hoh ) { debug("Must specify a grp hoh"); exit }

  # Find the top level groups and those that don't belong to any hiearchy
  my @top_lst   = grep !/\./, keys %ord_hoh;

  # Hierarchial Ordered List ( perl is cool eh?)
  my @ord_lst = keys %ord_hoh;
  @ord_lst = grep { s/(\d+)/sprintf("%03d",$1)/eg } @ord_lst;    # Need to 1 -> 001 for proper sorting
  @ord_lst = sort @ord_lst;                                      # so that 1..9,10,11 etc.
  @ord_lst = grep { s/(\d+)/sprintf("%d",$1)/eg } @ord_lst;

  # Get list of grp's that are ordered
  my @ord_grp_lst;
  foreach my $ref (values %ord_hoh ) {  push @ord_grp_lst, $ref->{'grp_id'}; }

  # and the lonely
  my @lone_lst;
  foreach my $grp_id ( keys %grp_hoh )
  {
    unless ( grep {$grp_id == $_ } @ord_grp_lst ) { push @lone_lst, $grp_id }
  }

  # Now assemble the object data structure
  my $self = bless {
                        'grp_hoh'  =>  \%grp_hoh,
                        'ord_hoh'  =>  \%ord_hoh,
                        'ord_lst'  =>  \@ord_lst,
                        'top_lst'  =>  \@top_lst,
                        'lone_lst' =>  \@lone_lst,
                    }, $class;

  return $self;
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

our %data;
sub bld_hiearchy
{
  my $self = shift @_;

  # Pass by reference
  my $arg_hsh_ref = shift @_;

  my $trex      = $arg_hsh_ref->{'template'} || debug "Requires Template Object";
  my $spacer    = $arg_hsh_ref->{'spacer'}   || '&nbsp;';
  my $code      = $arg_hsh_ref->{'code'};
  my $curr_ord  = $arg_hsh_ref->{'curr_ord'};
  my $fold      = $arg_hsh_ref->{'fold'};
  my $start_ptr = $arg_hsh_ref->{'start_ptr'};
  my %other_data = %{ $arg_hsh_ref->{'other_data'} };

  my @ord_lst;
  if     ( $start_ptr) { @ord_lst = grep /^$start_ptr/, @{ $self->{'ord_lst'} }  }
  elsif  ( $fold)      { @ord_lst = _fold( \@{ $self->{'ord_lst'} }, $curr_ord ) }
  else                 { @ord_lst = @{ $self->{'ord_lst'} }                      }

  my @lone_lst = @{ $self->{'lone_lst'} };

  my $str;
  foreach my $ord ( @ord_lst )
  {

     my $grp_id = $self->{'ord_hoh'}->{$ord}->{'grp_id'};
     my %data = %{ $self->{'grp_hoh'}->{$grp_id} };

     if ( %other_data ) { %data = ( %data, %other_data ) }

     $data{'ord'} = $ord;

     my $indent = $ord =~ tr/././;

     $data{'tab'} = $spacer x $indent;

     # execute code if supplied otherwise do the default action
     if ($code)  { $str .= eval($code); if ($@) { debug($@) }       }
     else        { $str .= $trex->render_sec('grp_row', { %data } ) }
  }

  return $str;
}

sub get_attr
{

   my $self = shift @_;
   my $param = shift @_;

   return($self->{$param});
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub bld_nav_path
{
  my $self = shift @_;

  # Pass by reference
  my $arg_hsh_ref = shift @_;

  #my $trex      = $arg_hsh_ref->{'template'} || debug "Requires Template Object";
  my $spacer    = $arg_hsh_ref->{'spacer'}   || '&nbsp;';
  #my $code      = $arg_hsh_ref->{'code'};
  my $curr_ord  = $arg_hsh_ref->{'curr_ord'};
  #my %other_data = %{ $arg_hsh_ref->{'other_data'} };

  my @curr_ord_lst = split /\./, $curr_ord;

  my @ord_lst;

  my @nav_h;
  push @nav_h, "<a href=?curr_ord=''&grp_id=''>Home</a>";

  foreach (@curr_ord_lst)
  {
    push @ord_lst, $_;
    my $ord = join ".", @ord_lst;

    my $grp_id = $self->{'ord_hoh'}->{$ord}->{'grp_id'};
    my $name   = $self->{'grp_hoh'}->{$grp_id}->{'name'};

    push @nav_h, "<a href=?action_default=1&curr_ord=$ord&grp_id=$grp_id>$name</a>";

  }

  $nav_h = join " / ", @nav_h;

  return $nav_h;
}

sub get_sub_folders
{
  my $self = shift @_;

  my $curr_ord = shift @_;

  my $ref = $self->{'ord_lst'};

  my @sub_lst = grep /^${curr_ord}\.\d+$/, @{$ref};

  my $loh_ref = _make_group_loh($self, @sub_lst);

  return ($loh_ref);

}
# - - - - - - - - - - - - - - - - - - - - - - - - - -
# Get a list of the top level groups (integer levels)
# - - - - - - - - - - - - - - - - - - - - - - - - - -
sub get_top_grps
{
  my $self = shift @_;

  my $ref = $self->{'ord_lst'};

  my @sub_lst = grep !/\./, @{$ref};  # get anything without a '.'

  my $loh_ref = _make_group_loh($self, @sub_lst);

  return ($loh_ref);


}
# - - - - - - - - - - - - - - - - - - - - - - - - - -
# Get a list of ALL sub groups below the curr ord level
# - - - - - - - - - - - - - - - - - - - - - - - - - -
sub get_sub_grps
{
  my $self = shift @_;

  my $curr_ord = shift @_;   # the ref group ord level

  my $ref = $self->{'ord_lst'};

  my @sub_lst = grep /^${curr_ord}\.(.*)\d+$/, @{$ref};

  my $loh_ref = _make_group_loh($self, @sub_lst);

  return ($loh_ref);

}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
# Get a list of next level groups (attached)
# - - - - - - - - - - - - - - - - - - - - - - - - - -
sub get_attached_grps
{
  my $self = shift @_;

  my $curr_ord = shift @_;   # the ref group ord level

  my $ref = $self->{'ord_lst'};

  my @sub_lst = grep /^${curr_ord}\.\d+$/, @{$ref};

  my $loh_ref = _make_group_loh($self, @sub_lst);

  return ($loh_ref);

}



#
# Form an LOH of group/ord info
#
sub _make_group_loh
{

  my $self = shift;
  my @ord_lst = @_;

  my @loh;
  foreach my $ord (@ord_lst)
  {
    my $grp_id = $self->{'ord_hoh'}->{$ord}->{'grp_id'};
    my %hsh = %{$self->{'grp_hoh'}->{$grp_id}};
    $hsh{'ord'} = $ord;
    push @loh, \%hsh;
  }

  return (\@loh);

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub bld_lone
{
  my $self = shift @_;

  # Pass by reference
  my $arg_hsh_ref = shift @_;
  my $trex       = $arg_hsh_ref->{'template'} || warn "Requires Template Object";
  my $code       = $arg_hsh_ref->{'code'}     || warn "Requires Code Block";
  my %other_data = %{ $arg_hsh_ref->{'other_data'} };

  my $lst_ref = shift @_;
  unless ( $lst_ref ) { $lst_ref = $self->{'lone_lst'} } # Assume the complete list

  my %data;
  my $str;
  foreach my $grp_id ( @{$lst_ref} )
  {
     unless ($grp_id) { next }
     my %data = %{ $self->{'grp_hoh'}->{$grp_id} };
     if ( %other_data ) { %data = ( %data, , %other_data ) }

     # execute code
     $str .= eval($code);
     if ($@) { debug($@) }
  }

  return \$str;
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub move_up
{
  my $self = shift @_;
  my $uniq = shift @_;

  ($super,$grp) = split /\./, $uniq;

debug($uniq);debug($self->{ord_hsh}); exit;

  my @uniq_lst = grep /$super\.\d+/, keys %{ $self->{ord_hsh} };

  @uniq_lst = sort { $self->{ord_hsh}->{$a} <=> $self->{ord_hsh}->{$b}   } @uniq_lst;

  for (my $i=0; $i<=$#uniq_lst; $i++)
  {
     if ( $uniq == $uniq_lst[$i] )
     {
        my $tmp = $uniq_lst[$i-1];
        $uniq_lst[$i-1] = $uniq_lst[$i];
        $uniq_lst[$i] = $tmp;
        last;
     }
  }

  my $tbl = "Store_grp_ord_" . $store_id;
  for (my $i=0; $i<=$#uniq_lst; $i++)
  {
     my ($super,$grp) = split /\./, $uniq_lst[$i];

     my $sql = "UPDATE $tbl SET ord = $i WHERE grp_id = $super, sub_grp_id = $grp";
     $rst = prepx($sql);

     #&Db_util::update_row($tbl,{'grp_id'=>$super,'sub_grp_id'=>$grp,'pos'=>$i },'grp_id' );

  }

  return;

}


# - - - - - - - - - - - - - - - - - - - - - - - - - - -
# private functions
# - - - - - - - - - - - - - - - - - - - - - - - - - - -


# - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Find collapsed fields..
# - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub _fold
{
  my @ord_lst  = @{ shift @_ };
  my $curr_ord = shift @_;

  my @curr_ord_lst = split /\./, $curr_ord;

  my @match_lst;
  my @pos_lst;
  foreach my $elem (@curr_ord_lst)
  {
    push @pos_lst, $elem;
    my $ord_str = join ".", @pos_lst;
    push @match_lst, '^' . ${ord_str} . '\.\d+$';
  }

  push @match_lst, '^\d+$';             # include top level grps
  $match_str = join "|", @match_lst;

  my @mem_lst;
  foreach my $ord ( @ord_lst )
  {
    if ( $ord =~ /($match_str)/ ) { push @mem_lst, $ord }
  }

  return @mem_lst;
}


$happy_note = 1;

__DATA__

# - - - - - - - - - - - - - - -
=pod

=head1 Name

HieGrp - Hiearchy Groupings of folders, object or collections of things

=head2 Synopis

 use HieGrp;

 $t_rex = new TemplateRex( $arg_hsh_ref );   # Arguments can be either a hash or hash reference

 Required input

 $arg_hsh_ref{'ord'} => %ord_hoh  where hoh of data of type

 +-------+--------+
 | ord   | grp_id |
 +-------+--------+
 | 1     |      1 |
 | 3     |      5 |
 | 3.1   |      4 |
 | 2     |      2 |
 | 2.1   |      3 |
 | 5     |      7 |
 | 3.1.1 |      8 |
 +-------+--------+


 $arg_hsh_ref{'grp'} => %grp_hoh  where hoh of data of type

 +--------+-------------+------+
 | grp_id | name        | dsc  |
 +--------+-------------+------+
 |      1 | Fish        | ...  |
 |      2 | Mammals     | ...  |
 |      3 | Marsupials  | ...  |
 |      4 | Birds       | ...  |
 |      5 | Predators   | ...  |
 |      7 | Camels      | ...  |
 |      8 | Kangaroo    | ...  |
 +--------+-------------+------+

=cut

