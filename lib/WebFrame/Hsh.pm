#-----------------------------------------------------------
# Hsh.pm - Hash Tools
#
#-----------------------------------------------------------

package Hsh;

use Exporter ();
use WebFrame::Debug ;

@ISA    = qw( WebFrame::Debug Exporter  );
@EXPORT = qw( hsh_open hsh_close );

#----------------------------------------------------
#  hsh_open() - exposes a hash's key=value variables
#
#  Inputs:  1. hash reference
#           2. prefix to desired hash name  (optional)
#              (e.g. %my_{keys}  )
#
#  Outputs: Global data in the form
#            $key = $value
#
#  Note: Potential issue here as a template can interject
#        Global data
#----------------------------------------------------
sub hsh_open
{
    my($hsh, $prefix) = @_;

    my ($pck,$file,$ln) = caller();

    if (  ref($hsh) ne "HASH" ) { debug("Opps Expecting Hsh Ref",$hsh) } ;

    if ( $prefix ) { $prefix = "${prefix}_" }

    foreach (keys %$hsh) {

        if ($_ =~ /^(db|cat|app)/) { next;}  # Do not create some var's

        $var  = "${pck}::${prefix}${_}";
        $$var = $$hsh{$_};

    }
}

#----------------------------------------------------
#  hsh_close() - deletes a hash's keys=value entries
#
#  Inputs:  1. hash reference
#           2. prefix to desired hash name  (optional)
#              (e.g. %my_{keys}  )
#
#  Outputs: None
#
#----------------------------------------------------
sub hsh_close
{
    my($hsh, $prefix) = @_;

    if (  ref($hsh) ne "HASH" ) { debug("Opps Expecting Hsh Ref") } ;

    my ($pck,$file,$ln) = caller();

    if ( $prefix ) { $prefix = "${prefix}_" }

    foreach (keys %$hsh) {
        $var = "${pck}::${prefix}${_}" ;
        undef $$var ;
    }
}

#$positive_note = 1;
