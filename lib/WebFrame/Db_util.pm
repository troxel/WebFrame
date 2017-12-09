package WebFrame::Db_util;

use 5.008;

#use strict;

#use warnings;

require Exporter;
#use AutoLoader qw(AUTOLOAD);

require DBI;

use WebFrame::Debug;

#use vars qw(@ISA);
our @ISA = qw(Exporter DBI DBI::db DBI::st WebFrame::Debug);

# This allows declaration use Example ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );

our @EXPORT_OK = qw(Dbh);

our @EXPORT = qw();

our $VERSION = '$Revision: 1.5 $';

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
  unless ( ( $arg_hsh{'DSN'} && $arg_hsh{'USR'} ) ) { debug("Must specify a DSN and USR") }

  # Override default hash with arguments
  #my %conf_hsh = __PACKAGE__->get_defaults();

  #%conf_hsh = (%conf_hsh, %arg_hsh);
  
  # Add the ability to set attributes
  my $default_attr_ref =  { PrintError => "0" , RaiseError => "0" }; 
  $arg_hsh{'attr'} = { %$default_attr_ref, %{ $arg_hsh{'attr'} } }; 

  my $Dbh = DBI->connect( $arg_hsh{'DSN'}, $arg_hsh{'USR'} ,$arg_hsh{'PSD'}, $arg_hsh{'attr'} ) || die ("$DBI::errstr");

  $arg_hsh{'DSN'} =~/DBI:(.*?):/i;
  my $Mode = $1;                 # Someday may use something other mysql

  # The object data structure
  my $self = bless $Dbh, $class;

  return $self;
}

# - - - - - - - - - - - - - - - - - -
# insert_row() Appends row to a table.
#
# $table   = Existing db table name
# $hsh_ref = Hash ref which keys match the col names in table
#
# - - - - - - - - - - - - - - - - - -
sub insert_row
{
   my ( $self, $table, $hsh_ref ) = @_;

   my ($col_ref, $val_ref) = $self->get_cols_vals($table, $hsh_ref);

   unless (scalar @{$col_ref}) { return -1 }

   if ( $val_ref->[0] eq 'NULL' ) { shift @{$col_ref}; shift @{$val_ref};  } # Assume first col is uniq key and not nullable

   my $col_str = join ",", @{$col_ref};
   my $val_str = join ",", @{$val_ref};

   my $sql = "INSERT INTO $table ($col_str) VALUES ($val_str)";

   my $sth = $self->prepx($sql);

   my $insert_id =  $sth->{'mysql_insertid'};

   $sth->finish;

   return $insert_id;
}

# - - - - - - - - - - - - - - - - - -
# update_row_null_blank_enums()
#
# This function is a wrapper for update_row below
# where missing enum data are nulled.  This function
# is useful for html forms that uses checkboxes.  When
# a checkbox is unselected it does not return from the
# form.  Calling this function with the Query hash will
# achieve the desired result of unchecking the enum types.
# - - - - - - - - - - - - - - - - - -
sub update_row_null_blank_enums
{
   my ( $self, $table, $hsh_ref, @wh_key_lst ) = @_;

   my @enum_lst = $self->get_enums($table);

   foreach my $enum ( @enum_lst )
   {
     unless ( defined $hsh_ref->{$enum} ) { $hsh_ref->{$enum} = 'NULL'  }
   }

   return update_row( $self, $table, $hsh_ref, @wh_key_lst );
}

# - - - - - - - - - - - - - - - - - -
# update_row() Update row to a table.
#
# $table      = Existing db table name
# $hsh_ref    = Hash ref which keys match the col names in table
# $wh_key_lst = List of keys to use for building the where clause
#
# - - - - - - - - - - - - - - - - - -
sub update_row
{
   my ( $self, $table, $hsh_ref, @wh_key_lst ) = @_;

   my ($col_ref, $val_ref) = $self->get_cols_vals($table, $hsh_ref);

   unless (scalar @{$col_ref}) { return -1 }

   my (@set_lst, @key_lst);
   foreach my $i (0..$#{$col_ref} )
   {
     if ( grep /\b$col_ref->[$i]\b/, @wh_key_lst )
     {
       push @key_lst, "$col_ref->[$i] = $val_ref->[$i]"
     }
     else
     {
       push @set_lst, "$col_ref->[$i] = $val_ref->[$i]";
     }
   }

   # skip if nothing to update
   unless (@set_lst) { return };

   my $set_str = join ", ", @set_lst;
   my $key_str = join " AND ", @key_lst;

   my $sql = "UPDATE $table SET $set_str WHERE $key_str";

   my $sth = $self->prepx($sql);
   $sth->finish;

   return $sth;
}

# - - - - - - - - - - - - - - - - - - - - - -
# select_row() Retrieve only one row of a table that
# matches the criteria, which is typical a unique id.
#
# $table    = Table name (ie. Customer)
# $fld_name = Field name (ie. CustomerID)
# $fld_val  = Field value
#
sub select_row
{
  my ($self, $table, $fld_name, $fld_val ) = @_;

  my $statement = "SELECT \* FROM $table WHERE $fld_name = $fld_val";

  # Different version of DBI
  #my $loh_ref = $Dbh->selectall_hashref($statement) || db_error();
  # We only want the first row (and there should only be one row)
  #my $hsh_ref = ${$loh_ref}[0];
  
  #my $hsh_ref = $self->selectrow_hashref($statement) || db_error($self);
  # OK hate to modify how this works since it is used everywhere but it 
  # should not be erroring out on a return with no data found.  
  my $hsh_ref = $self->selectrow_hashref($statement);
  if ( $DBI::err ) { db_error($self) }

  if ( wantarray ) { return %{$hsh_ref} }
  return $hsh_ref;
}

# - - - - - - - - - - - - - - - - - -
# prepx() Prepares and execute a SQL statement
#
# Assumptions:
# 1. This function assumes that there
# exists a database handle by the name $dbh
#
# 2. That PrintError is set.
#
# 3. That an __WARN__ signal handle function is set
#    up to handle thrown exceptions
#
# - - - - - - - - - - - - - - - - - -
sub prepx
{
   my $self = shift(@_);
   my $sql  = shift(@_);

   #my $sth = $self->prepare_cached($sql) || db_error($self);   # This causes the db to crash
   my $sth = $self->prepare($sql) || db_error($self);
   my $tst = $sth->execute() || db_error($self);

   return $sth;
}

# - - - - - - - - - - - - - - - - - -
# Prepare the columns and values 
# - - - - - - - - - - - - - - - - - -
sub get_cols_vals
{
   my $self      = shift @_;
   my $table     = shift @_;
   my $hsh_ref   = shift @_;

   unless( $table ) { debug("No Table Defined"); exit; }

   my %info_hsh = %{ $self->get_table_info($table) };

   my @name_lst = @{$info_hsh{'NAME'}};
   my @type_lst = @{$info_hsh{'TYPE'}};
   my @is_num   = @{$info_hsh{'IS_NUM'}};

   my @nullable_lst = @{$info_hsh{'NULLABLE'}};

   # Assemble value and col list
   my (@val_lst, @col_lst);
   for ( my $i=0; $i<=$#name_lst; $i++  )
   {
      my $name   = $name_lst[$i];
      my $type   = $type_lst[$i];
      my $is_num = $is_num[$i];

      unless ( defined $hsh_ref->{$name} ) { next }

      if ( $type =~ /^(9|10|11)$/ && $hsh_ref->{$name} =~ /^\D+/i )
      {
         push @val_lst, $hsh_ref->{$name};  # Do not quote Time Functions
      }
      elsif ( $is_num )
      {
         unless ( $hsh_ref->{$name} =~ /\d/ ) { $hsh_ref->{$name} = "''" }
         push @val_lst, $hsh_ref->{$name};
      }
      else
      {
         push @val_lst, $self->quote($hsh_ref->{$name}, $type);
      }

      push @col_lst , $name;
   }

   return (\@col_lst, \@val_lst, \@nullable_lst);
}

# - - - - - - - - - - - - - - - - -
sub get_table_info
{
   my $self  = shift @_;
   my $table = shift @_;

   unless ($table) { debug("No Table defined") }

   my %hsh;
   # Get column name from table

   my $sth = $self->prepx("SELECT * FROM $table LIMIT 1");
   #if    ( $Mode =~ /mysql/i ) { $sth = $self->prepx("SELECT * FROM $table LIMIT 1") }
   #elsif ( $Mode =~ /odbc/i  ) { $sth = $self->prepx("SELECT TOP 1 * FROM $table")   }
   #else                        { debug("Mode $Mode not supported")             }

   $hsh{'NAME'} = $sth->{NAME};
   $hsh{'TYPE'} = $sth->{TYPE};
   $hsh{'PRECISION'} = $sth->{PRECISION};
   $hsh{'NULLABLE'}  = $sth->{NULLABLE};

   $hsh{'IS_NUM'}  = $sth->{'mysql_is_num'};   # Another mysql'sm

   return \%hsh;
}

# - - - - - - - - - - - - - - - - -
sub get_tables
{
  my $self  = shift @_;
  my $sth = $self->table_info();

  my @tbl_lst;
  while ( my $ref = $sth->fetchrow_arrayref() )
  {
     if ( $ref->[3] eq "TABLE" ) { push @tbl_lst, $ref->[2] }
  }

  return \@tbl_lst;
}

# - - - - - - - - - - - - - - - - - -
# get_enums($table)
#
# - - - - - - - - - - - - - - - - - -
sub get_enums
{
   my $self      = shift @_;
   my $table     = shift @_;

   unless( $table ) { debug("No Table Defined"); exit; }

   my %info_hsh = %{ $self->get_table_info($table) };

   my @name_lst = @{$info_hsh{'NAME'}};
   my @type_lst = @{$info_hsh{'TYPE'}};
   my @nullable_lst = @{$info_hsh{'NULLABLE'}};

   # Assemble value and col list
   my @enum_lst;
   for ( my $i=0; $i<=$#name_lst; $i++  )
   {
      my $name     = $name_lst[$i];
      my $type     = $type_lst[$i];

      if( $type == 1 ) { push @enum_lst, $name }
   }

   return @enum_lst;
}

#  - - - - - - - - - - - - - - - - -
sub db_error
{
  my $self = shift;

  if ( $DBI::err ) { main::debug("ERROR $DBI::err,$DBI::errstr,$DBI::state, $!") }
  else             { main::debug($self->errstr)  }
  exit;
}

#$SIG{__DIE__} = \&db_error;

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


SQL DATA TYPEs


SQL_GUID=-11
SQL_WLONGVARCHAR=-10
SQL_WVARCHAR=-9
SQL_WCHAR=-8
SQL_BIT=-7
SQL_TINYINT=-6
SQL_LONGVARBINARY=-4
SQL_VARBINARY=-3
SQL_BINARY=-2
SQL_LONGVARCHAR=-1
SQL_UNKNOWN_TYPE=0
SQL_ALL_TYPES=0
SQL_CHAR=1
SQL_NUMERIC=2
SQL_DECIMAL=3
SQL_INTEGER=4
SQL_SMALLINT=5
SQL_FLOAT=6
SQL_REAL=7
SQL_DOUBLE=8
SQL_DATETIME=9
SQL_DATE=9
SQL_INTERVAL=10
SQL_TIME=10
SQL_TIMESTAMP=11
SQL_VARCHAR=12
SQL_BOOLEAN=16
SQL_UDT=17
SQL_UDT_LOCATOR=18
SQL_ROW=19
SQL_REF=20
SQL_BLOB=30
SQL_BLOB_LOCATOR=31
SQL_TYPE_DATE=91
SQL_TYPE_TIME=92
SQL_TYPE_TIMESTAMP=93
SQL_TYPE_TIME_WITH_TIMEZONE=94
SQL_TYPE_TIMESTAMP_WITH_TIMEZONE=95

=cut

