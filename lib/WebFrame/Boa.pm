#-----------------------------------------------------------
# BOA - Book of Acronyms
#-----------------------------------------------------------

package Boa;

# $Id: Boa.pm,v 1.5 2007/03/15 00:32:11 http Exp $

use Exporter;

our @ISA = qw(Exporter WebFrame::Debug);

@EXPORT = ( 'add_links', 'debug' );

# Include our friends
use WebFrame::Sys  ;
use WebFrame::Debug;
require WebFrame::Db_util;

#- - - - - - - - - - - - - - - - - - - - - - - -
# Constructor
#- - - - - - - - - - - - - - - - - - - - - - - -
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

  my $app_id  = $arg_hsh{'app_id'}  || 'boa';
  my $dsn_id  = $arg_hsh{'dsn_id'}  || die "Must specify the dsn_id";
 # my $node_id = $arg_hsh{'node_id'} || '%';
 # my $url     = $arg_hsh{'url'}     || '/boa/';

  my $fspec = "$main::Dir{home_wframe}/Apps/$app_id/$dsn_id/.conf.pm";

  my $conf = safe_read($fspec) || die "Cannot Open dsn_id configuration $fspec";

  my $dbh = WebFrame::Db_util->new( $conf );

  my $self = bless { 'url'       => $conf->{'url'} || '/boa/',
                     'dbh'       => $dbh,
                     'node_id'   => $conf->{'node_id'} || '%',
                     'link_type' => $arg_hsh{'link_type'} || 'popup',
                     'link_txt'  => $arg_hsh{'link_txt'}  || 'normal',
                     'conf'      => $conf,
                   }, $class;

  return $self;
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
# parse input text for acronyms and substitute links
# that launch the boa application to display
# the full description
# - - - - - - - - - - - - - - - - - - - - - - - - - -
sub add_links
{
  my $self = shift;
  my $text = shift;

  # Allow passing of a reference if desired.
  if (  ref($text) =~ "SCALAR" ) { $text = ${$text} };

  my $url = $self->{'url'};

  my $text_new;

  $hoh_ref = $self->get_node_hoh();

  foreach my $word ( split(/\b/,$text )  )
  {
     if ( length( $word ) < 3 ) { $text_new .= $word;  next; }

     if ( $hoh_ref->{$word} )
     {
            if($self->{'link_type'} eq 'popup')
            {
               $word = "<a class=\"boa\" href=\"javascript:; void window.open('$url?action_boa_showit=1&rec_id=$hoh_ref->{$word}->{rec_id}', '', 'toolbar=no, location=no, status=no, menubar=no, scrollbars=yes, resizable=yes, width=600,height=500,left=100,top=100');\">$word</a> ";
            }
            else
            {
               $word = "<a href=$url?action_boa_showit=1&rec_id=$hoh_ref->{$word}->{rec_id}>$word</a>";
            }
     }

     $text_new .= $word;
  }

  return(\$text_new);
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
sub get_rec
{
  my $self   = $_[0];
  my $rec_id = $_[1] || debug('No Rec ID specified');

  my $sql = "SELECT * FROM boa WHERE rec_id = \"$rec_id\"";
  my $hsh_ref = $self->{'dbh'}->selectrow_hashref($sql);

  return $hsh_ref;
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
sub get_node_hoh
{
  my $self    = $_[0];
  my $node_id = $_[1] || $self->{'node_id'} || debug('No Node ID specified');
 
  my $sql = "SELECT * FROM boa WHERE node_id LIKE \"$node_id\"";
  my $hoh_ref = $self->{'dbh'}->selectall_hashref($sql,'acronym');

  return $hoh_ref;
}


# - - - - - - - - - - - - - - - - - - - - - - - - - -
sub rmv_rec
{
  my $self   = shift @_;
  my $rec_id = shift @_ ;

  unless ( $rec_id )  { debug("$_ Required"); exit; }

  my $sql = "DELETE FROM boa WHERE rec_id = $rec_id";
  $self->{'dbh'}->prepx($sql);

  return 1;
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
sub put_rec
{
  my $self = shift @_;
  my %hsh;

  if ( ref($_[0]) eq "HASH" ) { %hsh = %{ shift @_ } }
  else                        { %hsh = @_ }

  unless  ( $hsh{'node_id'} ) { $hsh{'node_id'} = $self->{'node_id'} }

  foreach ( 'acronym', 'meaning', 'last_edit', 'usr_id', 'node_id' )
  {
    unless ( defined $hsh{$_} )  { debug("$_ Required"); exit; }
  }

  $hsh{'acroynm'} =~ s/^\s+//g; $hsh{'acroynm'} =~ s/\s+$//g;

  if ( $hsh{'rec_id'} )
  {
    $self->{'dbh'}->update_row('boa', { %hsh } ,'rec_id');
  }
  else
  {
    $hsh{'rec_id'} = $hsh{'last_edit'};
    $self->{'dbh'}->insert_row('boa', \%hsh );
  }
}

1;

__DATA__

  #my %data;
  #foreach my $acronym (keys %{ $self->{'hoh_ref'} } )
  #{
  #   $data{$acronym} = $hoh{$acronym}->{'meaning'};
  #}

