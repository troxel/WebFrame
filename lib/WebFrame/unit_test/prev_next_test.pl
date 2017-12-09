#!/usr/bin/perl
use lib "../../";

use WebFrame::Web;

@nums = (1,2,3,4,5,6,7,8);
@strs = qw(alpha beta charlie darla elanie fred);

foreach (1..8){
  ($p,$n) = prev_next(@nums, $_);
  print "prev:$p elem:$_ next:$n \n";
}

foreach (@strs){
  ($p,$n) = prev_next(@strs, $_);
  print "prev:$p elem:$_ next:$n \n";
}

exit;
