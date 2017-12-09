package LoH;

use Storable;
use WebFrame::Debug;

use Exporter ();
#@EXPORT = qw( eval_template eval_file eval_str );

@ISA    = qw( WebFrame::Debug Exporter);

# Synopsis
#
# use LoH ;
# $obj = new LoH ;
# $obj->store_loh() ;
#

sub new {

    my $class = shift @_;
    my $fspec    = shift @_;

    if (-e $fspec) {       $root = retrieve($fspec);
    }else{                 $root = [];               }

    bless  $root , $class ;

    return $root;
}

#-------------------------------------------
sub unshift_rec {

    my $obj     = shift @_;
    my $rec_ref = shift @_;

    unshift @$obj, $rec_ref ;

    return ($obj);
}

#-------------------------------------------
sub push_rec {

    my $obj     = shift @_;
    my $rec_ref = shift @_;

    push @$obj, $rec_ref ;

    return ($obj);
}

#-------------------------------------------
sub shift_rec {

    my($obj) = @_;

    return shift @{$obj}   ;
}

#-------------------------------------------
sub pop_rec {

    my($obj) = @_;

    return pop @{$obj}   ;
}

#-------------------------------------------
sub get_lst {

    my($obj) = @_;

    return \@{$obj}   ;

}

#-------------------------------------------
sub insert_entry {

    my ($obj)     = shift @_ ;
    my ($idx)     = shift @_ ;
    my ($hsh_ref) = shift @_ ;

    $obj->[$idx] = $hsh_ref ;

    return($obj);
}

#-------------------------------------------
sub store_obj {

    my ($obj)   = shift;
    my ($fspec) = shift;

    if (not $fspec) {
        debug("Cannot find file $fspec");
        return 0 ;
    }

    return store($obj,$fspec);
}

#-------------------------------------------
sub get_last_index {

    my($obj) = shift;

    return $#{$obj} ;

}

#-------------------------------------------
sub get_rec {

    my($obj) = shift;
    my($id)  = shift;

    return $obj->[$id] ;
}

# ----------------------
sub set_rec {

    my $obj = shift;
    my $rec_cnt = shift;
    my $hsh_ref = shift;

    if (  ref($hsh_ref) ne "HASH" ) { debug("Expecting Hsh Ref",$hsh_ref, ref $hsh_ref,$rec_cnt) } ;

    $obj->[$rec_cnt] = $hsh_ref ;

    return 1 ;

}


#-------------------------------------------
sub merge_rec {

    my ($obj)     = shift @_ ;
    my ($idx)     = shift @_ ;
    my ($in_hsh_ref) = shift @_ ;

    %rec_hsh = %{ $obj->[$idx] } ;

    %in_hsh = %{ $in_hsh_ref } ;

    $obj->[$idx] = { ( %rec_hsh , %in_hsh  ) } ;

    return($obj);
}

#-------------------------------------------
sub delete_rec {

    my($obj) = shift;
    my($id)  = shift;

    $obj->[$id] = {} ;

    return  ;
}
#-------------------------------------------
# Experimental sort function
#
#-------------------------------------------
sub sort_obj {

    my($obj)   = shift;
    my($param) = shift;
    my($order) = shift;

    my $value = $obj->[1]->{"$param"};

    my $number;
    if ($value =~ /^[\d\-\+]/) { $number = 1  }

    if ($number) {
        @{$obj} = sort { %a = %{$a} ; %b = %{$b} ; $b{$param} <=> $a{$param} }  @{$obj};
    }else{
        @{$obj} = sort { %a = %{$a} ; %b = %{$b} ; $b{$param} cmp $a{$param} }  @{$obj};
    }

    if ($order eq 'd') { @{$obj} = reverse(@{$obj}) }

    return $obj;
}

#-------------------------------------------
#   Filter loh object
#
#   < Removed erroneous comments >
#
#-------------------------------------------
sub filter {

    my($obj) = shift @_;

    my @and_rule = @{shift @_};
    my @or_rule  = @{shift @_};

    unless (@and_rule || @or_rule) { return $obj }

    @ref_loh = @{ $obj } ;

    my $or_eval_str;
    my @lst;
    foreach my $rule (@or_rule)
    {
       $rule =~ /^[\$]*(\w+)?(.*)/;
       push @lst , "( \$ref->{$1}$2 )";
    }

    if (@lst)
    {
      $or_eval_str = join " || ", @lst;
      $or_eval_str = "unless ( $or_eval_str ) { next }\n"; 
    }

    my $and_eval_str;
    foreach my $rule (@and_rule)
    {
       $rule =~ /^[\$]*(\w+)?(.*)/;
       $and_eval_str .= "  unless ( \$ref->{$1}$2 ) { next };\n";
    }

    my $push_str .= "   push \@filtered_loh, \$ref;\n";

    $eval_str = "foreach \$ref (\@ref_loh) {\n$or_eval_str $and_eval_str $push_str }\n";
 
    my @filtered_loh;
    eval($eval_str);

    # debug($eval_str); exit;
    
    # Nothing found ? return empty handed
    #if (not scalar @filtered_loh ) {  return 0 }
 
    @{$obj} = @filtered_loh;
    return $obj ;
}

#-------------------------------------------
#   LOH Debug print
#-------------------------------------------
sub loh_debug {

    my($obj) = shift;
    my $j = 0 ;

    foreach $ref ( @{$obj} )  {
       print "---------\nElement $j <br>\n";    $j++;
       foreach $key ( keys %{$ref} )  {
           print "$key = ${$ref}{$key} <br> \n"
       }
    }
}

