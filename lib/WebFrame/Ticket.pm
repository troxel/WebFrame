#------------------------------------------------------------
# Ticket Package
#
#------------------------------------------------------------
package WebFrame::Ticket;

use Exporter ();
@EXPORT_OK = qw( chk_ticket set_ticket rmv_ticket );

# Notes:
# 07/21/2017 Added checking for DN which fixes the bug where the last 
# user session was being resurrected. Powered down the IP checking to 0
# since no longer necessary with DN checking in place. SOT

# Constants 
# ---- Change these to desired values -----
my $ticket_dir = "/tmp/.ticket"; 
my $timeout_total = 12*3600;    # Maximum length of valid ticket (seconds)
my $timeout_inactive = 2*3600;   # Maximum length since last activity (seconds)
my $depth_ip_chk = 0;         
# - - - - - - - - - - - - - - -
sub set_ticket
{
  my $usr_id  = shift @_;
  my $ip_curr = shift @_;
  my $client_dn   = shift @_;

  unless ( $usr_id ) { die 'Requires usr as input' }
  unless ( $ip_curr ) { die "No remote IP found: $usr_id" }
  unless ( $client_dn ) { die "No CAC Distinguished Name: $usr_id" }
 
  $uid=getpwuid($<); 
 
  unless ( -d $ticket_dir ) { mkdir($ticket_dir, 0700) || die "Cannot create dir $ticket_dir for $uid $!"}; 
  
  # Remove any old ticket files 
  opendir(DID, $ticket_dir); 
  my @dir_lst = readdir(DID); 
  @file_lst = grep /^${usr_id}_/, @dir_lst;
  foreach my $user_file ( @file_lst ) { unlink "$ticket_dir/$user_file" }  
  
  my $ticket_id = "${usr_id}_" . int rand(1000000000000000); 
    
  my $fspec_ticket = "$ticket_dir/${ticket_id}"; 
  open(FID, ">$fspec_ticket") || die "Cannot make ticket file";
  my $time_curr = time;   
  print FID "$time_curr\n$time_curr\n$ip_curr\n$usr_id\n$client_dn"; 
  
  return $ticket_id; 
}

# - - - - - - - - - - - - - - -
sub chk_ticket
{
  my $ticket_id = shift @_;
  my $ip_curr   = shift @_;
  my $client_dn     = shift @_;
  
  unless ( $ticket_id ) { return (0, "no ticket_id") }
  unless ( $ip_curr )   { return (0, "no remote addr: $ticket_id") }
  unless ( $client_dn )     { return (0, "no CAC Distinguished Name") }
 
  my $fspec_ticket = "$ticket_dir/$ticket_id"; 
  open(FID, "+<$fspec_ticket") || return (0,"ssn $fspec_ticket not found: $ticket_id"); 
  
  my @lst = <FID>; 
  chomp @lst; 
  ($time_create,$time_last,$ip_last,$usr_id,$client_dn_last) = @lst;

  #-#   return (0,"$fspec_ticket : $time_last : $ip_last"); # debug inspection

  # Check IP address  
  if ( $depth_ip_chk < 4 ) 
  {  
    my $chk = chk_ip( $ip_curr,$ip_last,$depth_ip_chk ); 
    if ( $chk == 0 ) 
    { 
      return (0,"IP's $ip_last ne $ip_curr at depth $depth_ip_chk do not match: $ticket_id"); 
    }
  }             
  else 
  {
    if ( $ip_curr ne $ip_last )   { return (0,"IP's $ip_last ne $ip_curr do not match: $ticket_id"); }
  }
  
  if ( $client_dn ne $client_dn_last ) { return (0,"DN's $client_dn ne $client_dn_last do not match: $ticket_id"); }
    
  my $time_curr = time; 
  my $time_diff = $time_curr - $time_create; 
  if ( $time_diff > $timeout_total ) { return (-1,"Ticket max lifetime expiration $time_diff > $timeout_total : $ticket_id"); }

  my $time_diff = $time_curr - $time_last; 
  if ( $time_diff > $timeout_inactive ) { return (-1,"Ticket inactivity expiration $time_diff > $timeout_inactive : $ticket_id"); }
    
  seek(FID,0,0);
  print FID "$time_create\n$time_curr\n$ip_curr\n$usr_id\n"; 
  
  return (1,$usr_id); 
}

sub rmv_ticket
{
  my $ticket_id = shift @_;
  my $fspec_ticket = "$ticket_dir/${ticket_id}"; 
  
  my $rtn = unlink($fspec_ticket);
  return $rtn;
}

# ------------------------
sub chk_ip
{
 my $ip1 = shift @_;
 my $ip2 = shift @_;
 my $depth = shift @_ ;

 if ( $depth > 4 ) { die "Depth $depth greater than 4\n" }

 my @lst1 = split /\./, $ip1;
 my @lst2 = split /\./, $ip2;

 foreach my $inx (0..$depth-1)
 {
    print "$inx $lst1[$inx] $lst2[$inx]\n";
    unless ( $lst1[$inx] == $lst2[$inx] ) { return 0; }
 }

 return 1;
}
1;
