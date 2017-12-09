# List of temporary and oddball functions...


# ------------------------------------------------
sub get_nav_h
{
   unless ( $Dir{'rel'}) { debug("No Dir rel found") }

   my @lst = split /[\/]+/, $Dir{'rel'};

   my $dir_rel; my @rel;

   foreach my $dir ("",@lst)
   {
     my $hsh_ref;

     push @rel, $dir if ($dir); # avoid double slashes

     $dir_rel = join "/", @rel;

     my $fspec = "$Dir{'root'}/$dir_rel/.enode";
     if ( -e $fspec ) { $hsh_ref = parse_read($fspec) }

     if ( $hsh_ref->{'skip_nav'}  ) { next }

     unless ( $hsh_ref->{'name'} )
     {
       $hsh_ref->{'name'} = $dir;
       $hsh_ref->{'name'} =~ s/_/ /g;
     }

     push @url, "$icon<a href=$Url{root}/$dir_rel/>$hsh_ref->{'name'}</a>";
   }

   # remove the realm_home from the list now that the home icon is a hyper link
   # shift @url;

    my $realm_root = $Realm_obj->get('root_url');
    my $myhome = "$Url{root}$realm_root";

   unshift @url, "<a href=$myhome> <img src=/images/home.png border=0 align=middle></a>";
   my $src = join " > ", @url;

   return "$src";
}

# ------------------------------------------------
# Get list of managers and users
# This is a temporary hack and will be handled at the appro level once Auth/Realm/UserDb are reorg'd
sub get_mu_users_lst {

 # Get list of users that are at level 20 or above
 my @grp_lst = grep { $Usr{'grp2lvl'}->{$_} >= 20 } keys %{$Usr{'grp2lvl'}};

 my %uniq_hsh;

 foreach my $grp_id (@grp_lst)
 {
    my @lst =  $Realm_obj->get_usrs($grp_id);
    foreach (@lst) { $uniq_hsh{$_}++ }
 }

 return sort keys %uniq_hsh;
}


# ------------------------------------------------
# Get list of managers and users
# This is a temporary hack and will be handled at the appro level once Auth/Realm/UserDb are reorg'd
sub get_users_w_lvl {

 my $lvl = shift @_;
 # Get list of users that are at level 20 or above
 my @grp_lst = grep { $Usr{'grp2lvl'}->{$_} >= $lvl } keys %{$Usr{'grp2lvl'}};
 @grp_lst = grep !/global/, @grp_lst;

 my %uniq_hsh;

 foreach my $grp_id (@grp_lst)
 {
    my @lst =  $Realm_obj->get_usrs($grp_id);
    foreach (@lst) { $uniq_hsh{$_}++ }
 }

 return sort keys %uniq_hsh;
}

# - - - - - - - - - - - - - - - - - - - -
#sub _get_edit_upld_section
#{
#    my $num    = shift @_;
#    my $rec_id = shift @_;
#    my $trx    = shift @_;
#
#    my $sql = "Select * From upld Where rec_id = $Query{'rec_id'}";
#    my $upld_ref = $Dbh->selectall_hashref($sql,'seq');
#
#    my @x_lst = keys %{$upld_ref}
#
#    my $not_done = 1;
#    my $cnt =0;
#    while ( $not_done  )
#    {
#       $cnt
#       my %hsh = %{ $upld_ref->{$seq} };
#       my $fspec = _get_upld_dir($rec_id) . "$fspec/$hsh{fname}";
#
#       $hsh{'size'} = sprintf("%.1f", (stat($fspec))[7] / 1000);
#
#       $hsh{'url'} = "<a target=\"\" href=\"?action_get_file=1&rec_id=$rec_id&fname=$hsh{fname}\">$hsh{fname}</a>";
#       $t = $trx->render_sec('edit_upld_row', { %hsh } );
#    }
#    $trx->render_sec('edit_upld_sec');
#
#    return 1;
#}
#

# - - - - - - - - - - - - - - - - - - - -
# Render upload sections
#
# relavent template sections
#  'edit_upld_row' and 'edit_upld_sec'
#  'upld_row'      and 'upld_sec'
# - - - - - - - - - - - - - - - - - - - -
sub _get_upld_sections
{
    my $trx    = shift @_;
    my $rec_id = shift @_;
    my $new_num  = shift @_;

    my $sql = "Select * From upld Where rec_id = $rec_id";
    my $upld_ref = $Dbh->selectall_hashref($sql,'seq');

    # The trick below is to generate list of seq of existing and new upld rows
    # and fill in the holes made from prev rmv's if new upld are requested
    my $exist_num = scalar keys %{$upld_ref};

    unless ( $new_num || $exist_num ) { return 0 }

    my $seq; my $exist_cnt = 1; my $new_cnt = 1;

    while ( ( $exist_cnt <= $exist_num ) || ( $new_cnt <= $new_num ) )
    {
       $seq++;
       my %hsh = %{ $upld_ref->{$seq} };
       my $fspec = _get_upld_dir($rec_id) . "$fspec/$hsh{fname}";

       $hsh{'size'} = sprintf("%.1f", (stat($fspec))[7] / 1000);

       $hsh{'url'} = "<a target=\"\" href=\"?action_get_file=1&rec_id=$rec_id&fname=$hsh{fname}\">$hsh{fname}</a>";

       my $section;
       if ( $upld_ref->{$seq} )
       {
         $section = 'edit_upld_row';
         $exist_cnt++
       }
       elsif ( $new_cnt <= $new_num   )
       {
         $section = 'upld_row';
         $new_cnt++;
         $hsh{'title_seq'} = $Query{"title_$seq"}; # New upld title fields so that they are repopulated on a new upld_req
         $hsh{'seq'} = $seq;
       }
       else { next }

       $trx->render_sec( $section, { %hsh } );
    }

    if ( $exist_num ) { $trx->render_sec('edit_upld_sec') }
    if ( $new_num  =~ /^\d+/ ) { $trx->render_sec('upld_sec') }

    return 1;
}



# - - - - - - - - - - - - - - - - - - - -
sub _get_upld_popup
{
    my $upld_req = shift @_;
    my $trx      = shift @_;

    my $action = $Query{ACTION} || 'default';

    my $java_upld_popup =  "
     <script language=JavaScript>
     <!--
     function SendSubmit(FormName)
     {
       document.forms[0].elements[0].name  = \'action_$action\'
       document.forms[0].elements[0].value = 1
       document.forms[0].submit()
     }
     --></script>\n";

    # Sticky cgi.pm seem to override -default etc.
    unless ( $Query->delete('upld_req') ) { $Query->delete('upld_req') }
    my $upld_popup = $Query->scrolling_list(-name=>"upld_req",
                                         -values=>['Select Upload',1..7],
                                         -size=>1,
                                         -multiple=>'0',
                                         -onchange=>'SendSubmit()'  );

   return $upld_popup;
}

# - - - - - - - - - - - - - - - - - - - -
# Expecting input such as upld_\d+ where
# $1 is a sequence of numbers with 0 signifying
# the main document...
sub _hdl_upld
{

  my $rec_id = shift @_;
  unless ($rec_id =~ /\d+/ ) { debug('No rec_id found'), exit; }

  my $upld_dir = _get_upld_dir($rec_id);

  # save info in db and move prev file
  my $sql = "SELECT * FROM upld WHERE rec_id = $rec_id";
  my $upld_hoh_ref = $Dbh->selectall_hashref($sql,'seq');

  my @upld_lst = grep /upld_\d+/, keys %Query;

  foreach my $upld ( sort @upld_lst)
  {
    my ($seq) = $upld =~ /upld_(\d+)/;
    unless ( $seq =~ /\d+/ ) { debug("No sequence number found in $upld"), exit; }

    my $fname = $Query{$upld};

    ##    unless ( $fname ) { next } # removed this line as the remove function wasn't working. SOT 1/24/14

    $fname =~ s/.*\\//;           # IE gives the complete file path and must be removed
    $fname =~ s/[^\w\.\-\~]+/_/g; # clean name

    my $title = $Query{"title_${seq}"};
    my $rmv   = $Query{"rmv_${seq}"};

    my %upld_hsh = %{ $upld_hoh_ref->{$seq} };
    if ( %upld_hsh )
    { # Existing File

      # Select which what is being updated or removed.
      my $where = "rec_id=$rec_id AND seq=$seq";
      my $sql = "UPDATE upld SET title=\"$title\" WHERE $where";
      if    ( $rmv   ) { $sql = "DELETE FROM upld WHERE $where" }
      elsif ( $fname ) { $sql = "UPDATE upld SET fname=\"$fname\", title=\"$title\", mtime=NOW() WHERE $where";}

      my $sth = $Dbh->prepx($sql);
      $sth->finish;

      if ( $rmv || $fname )
      {
         my $prev_fname = $upld_hsh{'fname'};
         $upld_hsh{'mtime'} =~ /([\w-]+)\s*([\w:]+)/;
         my ($date, $time) = ($1, $2);

         $prev_fspec = "$upld_dir/${prev_fname}";
         $hist_fspec = "$upld_dir/encl-${seq}_date-${date}-${time}_usr_id-$Usr{usr_id}_fname-${prev_fname}";

     `mv $prev_fspec $hist_fspec`;
      }
    }
    else
    { # New File
      my $sql = "INSERT INTO upld (rec_id ,fname ,title, seq, mtime) VALUES ($rec_id,\"$fname\",\"$title\", $seq, NOW())";
      my $sth = $Dbh->prepx($sql);
      $sth->finish;
    }

    if ( $fname )
    { # Do the upload
      $saved_fspec = "$upld_dir/$fname";

      my $fh = $Query->param($upld);
      if ($fh) { file_upload($fh, $saved_fspec) }

      # now grab all text out of file and insert into database for
      # detailed search
      $saved_fspec =~ /\.(\w+)$/;
      $ext = $1;
      if ($ext eq "pdf")
      {
        $cmd = "/usr/local/bin/pdftotext $upld_dir/$fname /tmp/tempPDF.txt";
        `$cmd`;
        open (FID, "/tmp/tempPDF.txt");
        @text = <FID>;
        close FID;
        unlink "/tmp/tempPDF.txt";
        foreach my $line (@text){$body = "$body $line"}
      }

      elsif( ($ext eq "doc") )
      {
        $cmd = "/usr/bin/antiword $upld_dir/$fname";
        $body = `$cmd`;
      }

      elsif( ($ext eq "docx") )
      {
        $cmd = "/usr/local/bin/docx2txt.pl $upld_dir/$fname - ";
        $body = `$cmd`;
      }

      elsif( ($ext eq "xls") )
      {
        $cmd = "/usr/local/bin/xls2csv $upld_dir/$fname";
        $body = `$cmd`;
      }
      elsif( ($ext eq "ppt") )
      {
        $cmd = "/usr/local/bin/catppt $upld_dir/$fname";
        $body = `$cmd`;
      }

      elsif(($ext eq "txt")||($ext eq "ini")||
            ($ext eq "html")||($ext eq "xml")||
            ($ext eq "log")||($ext eq "pl")||
            ($ext eq "c")||($ext eq "h")||
            ($ext eq "cpp"))
      {
         open (FID, "$upld_dir/$fname");
         @text = <FID>;
         close FID;
         foreach my $line (@text){$body = "$body $line";}

      }
      else
      {
        next;# Do nothing;  No file that we can get text from
      }

      $args_ref->{body}    = $body;
      $args_ref->{rec_id}  = $rec_id;
      $args_ref->{title}   = $title;
      $args_ref->{fname}   = $fname;
      $args_ref->{seq}     = $seq;
      $args_ref->{node_id} = $Conf{src}{node_id};

      my $sql  = "SELECT rec_id,node_id, title, fname, seq FROM search WHERE rec_id = $rec_id AND node_id=$args_ref->{node_id} AND seq = $seq";

      $return_ref = $Dbh->selectrow_hashref($sql);

      if ($return_ref)
      {
        $Dbh->update_row('search', $args_ref, 'seq');
      }
      else
      {
        $Dbh->insert_row('search', $args_ref);
      }
    }
  }
}

# move the requested directory to the attic
sub _rmv_upld
{
  my $rec_id = shift @_;

  my $upld_dir = _get_upld_dir($rec_id);

  my $attic_dir = "$upld_dir/attic";

  unless ( -e $attic_dir ) { mkdir $attic_dir }

  `mv $upld_dir $attic_dir`;

  return 1;
}


# ------------------------------

# - - - - - - - - - - - - - - - - - - - -
sub cb_get_file
{
   # Remove ver/time footer.
   $WebFrame::Foot_info_flg = 0;

   my $mime_file = "$Dir{home_wframe}/Apps/mime.types";
   my @lst = read_file($mime_file);  chomp @lst;

   my ($ext) = $Query{'fname'} =~ /\.(\w+)$/;

   my $mime = 'text/plain';
   foreach (@lst)
   {
     ($m,$e) = split /\t+/;
     if ($e =~ /\b$ext\b/i ) { $mime=$m; last }
   }

   my $upld_dir = _get_upld_dir($Query{'rec_id'});
   my $fspec = "$upld_dir/$Query{'fname'}";
   if (! -e $fspec)
   {
     debug("Oops, $Query{'fname'} can not be found");
     exit;
   }

   my $size = -s $fspec;

   my $hdr = "Content-Disposition: attachment; filename=\"$Query{fname}\"\n";
   $hdr .= $Query->header('-type'=>$mime,'-Content-Length'=>$size);

   open FID, $fspec || debug("Cannot Open $fspec");

   print $hdr;

   while ( read(FID, $buf, 65536) )
   {
     print $buf;
   }

   exit;
}


sub _preserve_file
{
   my $prev_file = shift;
   my $upld_dir = _get_upld_dir($rec_id);
}

# - - - - - - - - - - - - - - - - - - - -
sub _get_upld_dir
{
  my $rec_id = shift @_;

  my $inx =  int( ($rec_id + 1) / 2000 );

  my $upld_dir = "$main::Dir{'app_root'}/upload_${inx}/$rec_id";
  unless ( -e $upld_dir ) { mkdir $upld_dir }

  return $upld_dir;
}

# - - - - - - - - - - - - - - - - - - - -
sub get_conf
{
  my $my_dir = shift @_ || $Dir{'src'};
  my %Conf;

  my $fspec = "$my_dir/.conf.pm";
  if ( -e $fspec) { $Conf{'src'} = safe_read($fspec) }

  $Dir{'app'} = "$Dir{home_wframe}/Apps/$Conf{'src'}->{app_id}";
  
  my $fspec = "$Dir{'app'}/.conf.pm";
  if ( -e $fspec) { $Conf{'app'} = safe_read($fspec) }

  unless ( $Conf{'src'}->{'dsn_id'} ) { $Conf{'src'}->{'dsn_id'} = 'main' }

  $Dir{'dsn'} = "$Dir{'app'}/$Conf{'src'}->{dsn_id}";

  my $fspec = "$Dir{'dsn'}/.conf.pm";

  if ( -e $fspec) { $Conf{'dsn'} = safe_read($fspec) || die "Cannot Open $fspec" }
  return %Conf;
}

# - - - - - - - - - - - - - - - - - - - -
sub read_stats
{
  my $conf_ref = shift @_;

  my $my_dir = $Dir{'src'};
  my $fspec;
  my $stats_ref;

  if(%Conf){

      $fspec = "$Dir{'dsn'}/$Conf{'src'}->{'node_id'}/.stat.pm";

  }else{

      $fspec = "$Dir{'home_wframe'}/Apps/$conf_ref->{'app_id'}/$conf_ref->{'dsn_id'}/$conf_ref->{'node_id'}/.stat.pm";

  }

  if ( -e $fspec){ $stats_ref = safe_read($fspec)}

  if (not $stats_ref->{'last_update'}){undef $stats_ref->{'last_update'} ;}
  if (not $stats_ref->{'count'}){$stats_ref->{'count'} = 0;}

  return $stats_ref;
}


# - - - - - - - - - - - - - - - - - - - -
sub write_stats
{

  my $stats_ref = shift @_;

  my $my_dir = $Dir{'src'};

  unless ( -e "$Dir{'dsn'}/$Conf{'src'}->{'node_id'}" ) { mkdir "$Dir{'dsn'}/$Conf{'src'}->{'node_id'}" }

  my $fspec = "$Dir{'dsn'}/$Conf{'src'}->{'node_id'}/.stat.pm";

  if ( not $stats_ref->{'count'}){ $stats_ref->{'count'} = 0}
  if ( not $stats_ref->{'last_update'} ) {$stats_ref->{'last_update'} = time }


  safe_write("$fspec", $stats_ref);

}

1;

