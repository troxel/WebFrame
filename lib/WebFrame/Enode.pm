package WebFrame::Enode;

use 5.008;

use strict;
use warnings;

require Exporter;
#use AutoLoader qw(AUTOLOAD);

use WebFrame::Debug;
use WebFrame::Sys;
use WebFrame::Save;

our @ISA = qw(WebFrame::Debug WebFrame::Sys WebFrame::Save);

our @EXPORT_OK = qw(find_file);

our $VERSION = '$Revision: 1.4 $';

# - - - - - - - - - - - - - - - -
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
  my $dir_root = $arg_hsh{'root'} || $WebFrame::Dir{'root'};
  unless ( $dir_root ) { debug("Must specify the root dir parameter") }

  my $dir_rel  = $arg_hsh{'rel'}  || $WebFrame::Dir{'rel'};
  #unless ( $dir_rel ) { debug("Must specify the relative dir parameter") }

  my $dir_src  = $arg_hsh{'src'}  || $WebFrame::Dir{'src'};
  unless ( $dir_src ) { debug("Must specify the src dir parameter") }

  # The object data structure
  my $self = bless {
                     'dir_root' => $dir_root,
                     'dir_rel'  => $dir_rel,
                     'dir_src'  => $dir_src,
                   }, $class;

  return $self;
}

# - - - - - - - - - - - - - - - - - - -
sub get_realm
{

 my $self = shift @_;
 my @file_lst = reverse $self->find_file('.htaccess'); # reverse so that first one wins

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
sub get_enode
{

 my $self = shift @_;
 my @file_lst = reverse $self->find_file('.enode');

 my %enode;
 foreach my $fspec (@file_lst)
 {
     my %hsh = parse_read($fspec);

     %enode = (%hsh, %enode ); # merge with priority on lower level data

     if ( $hsh{'allowoverride'} )
     {
        if ( $hsh{'allowoverride'} =~ /none/i ) { last }  # Stop processessing
     }
 }

 if (wantarray) { return %enode }
 else           { return {%enode} }
}


# - - - - - - - - - - - - - - - - - - -
sub get_grps
{
  my $self = shift;

  my %enode = $self->get_enode();

  my @enode_grps = grep /grp_[\w-]+/, keys %enode;

  # grep out group keys
  my %grp2lvl;           # relates grp_id to lvl from enode position
  foreach (@enode_grps)
  {
     /grp_([\w-]+)/;
     $grp2lvl{$1} = $enode{$_};   # Set the access level
  }

  return %grp2lvl;
}

# ------------------------------------------------
sub get_nav_h
{
   #unless ( $Dir{'rel'}) { debug("No Dir rel found") }

   my $self = shift @_;

   my $postfix = shift @_;

   my @lst = split /[\/]+/, $self->{'dir_rel'};

   my $dir_rel; my @rel;

   my $realm_root = $main::Realm_obj->get('root_url');
   my $myhome = "$main::Url{root}$realm_root";

   # Remove the / so that we can compare in the loop
   my $naked_realm_root = $realm_root;
   $naked_realm_root =~ s/\///g;

   my @url;
   foreach my $dir ("",@lst)
   {
     # If realm_root is defined then we only want to
     # show from the realm_root down.
     if ( $naked_realm_root  eq $dir )
     {
        @url = ();
     }

     my $hsh_ref;

     push @rel, $dir if ($dir); # avoid double slashes

     $dir_rel = join "/", @rel;

     my $fspec = "$self->{'dir_root'}/$dir_rel/.enode";
     if ( -e $fspec ) { $hsh_ref = parse_read($fspec) }

     if ( $hsh_ref->{'skip_nav'}  ) { next }

     unless ( $hsh_ref->{'name'} )
     {
       $hsh_ref->{'name'} = $dir;
       $hsh_ref->{'name'} =~ s/^\d+__//;
       $hsh_ref->{'name'} =~ s/_/ /g;
     }

     push @url, "<a href=/$dir_rel/>$hsh_ref->{'name'}</a>";
   }

   # remove the realm_home from the list now that the home icon is a hyper link
   shift @url;

   unshift @url, "<a href=$myhome> <img src=/Apps/images/home.png border=0 align=middle></a>";

   if ( $postfix) { push @url, $postfix;}

   my $src = join " > ", @url;

   return "$src";
}


# - - - - - - - - - - - - - - - - - - -
sub get_nav_v
{

 my $self = shift @_;
 my @file_lst = reverse $self->find_file('.');

 debug(\@file_lst);exit;
}

# - - - - - - - - - - - - - - - - - - -
sub find_file
{
  my $self = shift @_;
  my $file_name = shift @_;

  my $sep = '/';  # unix like file systems only - for now

  my @rel_lst = split /$sep/, $self->{'dir_rel'};

  my @file_lst;

  my $fspec = join "$sep", ( $self->{'dir_root'}, $file_name) ;
  if (-e $fspec) { push @file_lst, $fspec }

  for ( my $i = 0; $i <= $#rel_lst; $i++ )
  {
    $fspec = join "$sep", ( $self->{'dir_root'}, @rel_lst[0..$i], $file_name) ;

    if (-e $fspec) { push @file_lst, $fspec }
  }

  return @file_lst;
}

# - - - - - - - - - - - - - - - - - - -
# Return a nicely formatted directory
# listing via a template object
# - - - - - - - - - - - - - - - - - - -
sub format_index
{
  my ($self, $trex) = @_;

  my ($dir_ref, $file_ref) = $self->get_index_lst();

  foreach my $ref ( @{$dir_ref} )
  {
    $trex->render_sec('dir_row', $ref );
  }

  foreach my $ref ( @{$file_ref} )
  {

    my $icon = "ascii.gif";
    if ( $ref->{url} =~ /html$/i ) { $icon = "html.gif" }
    elsif ( $ref->{url} =~ /doc$/i )  { $icon = "worddoc.gif" }
    elsif ( $ref->{url} =~ /pdf$/i )  { $icon = "pdf.gif" }
    elsif ( $ref->{url} =~ /png$/i )  { $icon = "icon_png_0.png" }

    $ref->{'icon_img'} = "/Apps/images/$icon";

    $trex->render_sec('file_row', $ref );
  }
}

# - - - - - - - - - - - - - - - -
#
# - - - - - - - - - - - - - - - -
sub get_index_lst
{
   my $self = shift @_;

   my (@dir_loh, @file_loh);

   my $src = $self->{'dir_src'};

   my @lst = ls($src,'^[^\.]');

   @lst = sort @lst;

   foreach my $i ( @lst )
   {
     my %hsh;
     if ( -d "$src/$i" )
     {
        if ( $i =~ /_files$/ ) { next }
        $hsh{'url'}  = "$main::Url{'src'}/$i";
        $hsh{'name_fmt'} = _get_dir_name($i);
        push @dir_loh, \%hsh;
     }
     else
     {
        $hsh{'url'}  = "$main::Url{'src'}/$i";
        $hsh{'name_fmt'} = _get_file_name($src,$i);
        my @stat_lst = stat "$src/$i";

        $hsh{'size'}  = $stat_lst[7];
        $hsh{'atime'} = $stat_lst[8];

        push @file_loh, \%hsh;
     }
   }

   return \@dir_loh, \@file_loh;
}

sub _get_dir_name
{
 my $name = shift;

 $name =~ s/^\d+__//g;
 $name =~ s/_/&nbsp;/g;
 return $name;
}

sub _get_file_name
{
 my ( $src, $name_in ) = @_;
 my $name_out;

 if ( $name_in =~ /\.html/ ) { $name_out = _get_html_title("$src/$name_in") }

 unless ( $name_out ) { $name_out = _get_raw_name($name_in)  }

 return $name_out;
}

sub _get_raw_name
{
 my $doc = shift;

 $doc =~ s/^\d+__//;
 $doc =~ s/_/ /g;
 $doc =~ s/\..*/ /g;
 #$doc = "\u$doc";

 return $doc;
}

sub _get_html_title
{
 my $fspec = shift;

 my @lst = read_file($fspec);

 foreach ( @lst )
 {
   if ( /\<title\>([^\<]+)/ ) { return $1 }
 }

}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Example - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Example;
  blah blah blah

=head1 ABSTRACT

  This should be the abstract for Example.
  The abstract is used when making PPD (Perl Package Description) files.
  If you don't want an ABSTRACT you should also edit Makefile.PL to
  remove the ABSTRACT_FROM option.

=head1 DESCRIPTION

Stub documentation for Example, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

A. U. Thor, E<lt>troxelso@localdomainE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by A. U. Thor

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

