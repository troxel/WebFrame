# Include our friends
use lib "../";
use Web  ;
use Hsh  ;      # hsh_open() hsh_close()
use Sys  ;      # ls() read_file() save_file()
use Save ;
use TemplateRex ;  # render_sec() , render()

use Debug;

my $file_out = 'test_output/unit_test.html';
my $temp_in  = 't-unit_test.html';

unlink $file_out;

my @lst = ('INC','ENV');

my $trex = new TemplateRex({'file'=>$temp_in} );

%hsh = TemplateRex->get_defaults();
TemplateRex::set_defaults(\%hsh);

%hsh = TemplateRex->get_defaults();
TemplateRex->set_defaults(\%hsh);

#%hsh = $trex->get_defaults();
#$trex->set_defaults(%hsh);




foreach $hsh_name (@lst)
{
  foreach $key ( keys %{$hsh_name} )
  {
    ($value) = ${$hsh_name}{$key} =~ /(.{0,45})/; # limit the width

    $trex->render_sec('inner_row', { 'key'=>$key, 'value'=>$value } );
  }

  $trex->render_sec('tbl', { 'hsh_name'=>$hsh_name } );

}

$trex->render_sec('rim');

$trex->render(\%ENV, $file_out );

sub _get_time { localtime }

$positive_note = 1;

__DATA__
