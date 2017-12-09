package Keyword ;

use WebFrame::Debug;
use WebFrame::Sys;

use Exporter ();
#@EXPORT = qw( eval_template eval_file eval_str );

@ISA    = qw( WebFrame::Debug Exporter Sys );

# Synopsis
#
# use Keyword ;
# $obj = new Keyword ;
# @lst = $obj->stop_word_filter($str) ;
#

sub new {

    my $class = shift @_;
    my $fspec    = shift @_;

    if (-e $fspec) {  $ref = read_file($fspec)            }
    else           {  $ref = read_file("./stopwords.txt") }

    chomp @{$ref} ;

    bless  $ref , $class ;

    return  $ref ;
}

######################
#  In: String to parse
# Out: Array Reference
######################
sub stop_word_filter {

  my $obj = shift ;

  my $str = shift ;

  $str =~ s/^\s+// ;
  $str =~ s/\b\w{1,3}\b//g ;
  $str =~ s/<[^>]*>?/ /g ;
  $str =~ s/[\.\"\,\?\!\-\(\)\{\}\'\`\>\:\$\/\\\%\^\*]+//g ;

  my @lst = split /\s+/ , $str ;

  #if (! @stopword_lst) {
  #  @stopword_lst = read_file("./stopwords.txt");
  #}

  @stopword_lst = @{ $obj } ;

  @short_lst = ();
  WD: foreach $wd  (@lst) {

        if (! $wd) { next }

        $wd = lc($wd);

        foreach $stop_wd  (@stopword_lst) {

           if ($wd =~ /^$stop_wd$/i ){ next WD }
        }

        push @short_lst , $wd ;
  }

  return \@short_lst ;
}

1;
