#--------------------------------------------------------
#  Use system sendmail
#
#  send_mail($hsh_ref,$mode,$sendmail)
#
#  $hsh_ref - reference to a hsh that include all head parameters
#  listed by key and a special msg key. For example the refernced
#  hash should include fields for To,From,msgetc.
#
#  $mode - 'text' or 'html' default is text
#
#  $sendmail = file spec of sendmail program if not pathed.
#
#--------------------------------------------------------

package WebFrame::Email;

use Exporter ();
use WebFrame::Debug ;

@ISA = qw( WebFrame::Debug Exporter );
@EXPORT = qw( send_mail );

sub send_mail {

  my $hsh_ref = shift @_;

  unless (ref $hsh_ref) { debug("Expecting a Reference") }
  my %hsh = %{$hsh_ref};

  my $mode = shift @_;
  if (not $mode) { $mode = "text" }

  my $sendmail = shift @_;
  if (not $sendmail) { $sendmail = "sendmail" }

  my $email_str;
  foreach ( keys %hsh )
  {
    if ($_ eq 'msg') { next }
    if (! $_) { next }
    $email_str .= "${_}: $hsh{$_}\n"
  }

  if ($mode =~ /html/i)
  {
    $email_str .= "Mime-Version: 1.0\n";
    $email_str .= "Content-Type: Text/HTML; charset=US-ASCII\n";
  }

  $email_str .= "\n$hsh{msg}";

  if ( open(MID, "|$sendmail -t") )
  {
      print MID $email_str;
      close MID;
  }
  else
  {
     debug("Error cannot open $sendmail $!");
  }

}

$positive_note = 1;
