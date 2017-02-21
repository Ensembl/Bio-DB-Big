=head1 LICENSE

Copyright [2015-2017] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package Bio::DB::Big::AutoSQL;

=pod

=head1 NAME

Bio::DB::Big::AutoSQL

=head1 SYNOPSIS

  my $raw_autosql = $bb->get_autosql();
  my $as = Bio::DB::Big::AutoSQL->new($raw_autosql);
  foreach my $field (@{$as->fields()}) {
    printf("%d: %s (%s)\n", $field->position(), $field->name(), $field->type());
  }

=head1 DESCRIPTION

Provides access to an AutoSQL definition by parsing a raw AutoSQL file into this object (representing the overall definition) and a series of L<Bio::DB::Big::AutoSQLField> objects. Fields can be looped over in the order they appear or can be retrieved by name.

=head1 METHODS

=cut

use strict;
use warnings;
use Carp;

use Bio::DB::Big::AutoSQLField;

# Parse a name e.g. name
my $NAME_RX = qr/[a-z0-9_]+/ixms;
# Extract string from a quoted string e.g. "A description."
my $QUOTEDSTR_RX = qr/"(.+?)"/xms;
# Capture field size e.g. int[2]
my $FIELDSIZE_RX = qr/\[(\w+)]/xms;
# Capture field values e.g. enum(one,two, three)
my $FIELDVALUES_RX = qr/\(([a-z, ]+)\)/xms;

# Capture all types of fields
my $FIELDSTYPE_RX = qr/(int|uint|short|ushort|byte|ubyte|float|char|string|lstring|enum|set)/xms;
# Capture index types e.g. primary or unique[12]
my $INDEX_RX = qr/(primary|index|unique) $FIELDSIZE_RX?/xms;
# Capture auto declaration
my $AUTO_RX = qr/\s(auto)/xms;

# Capture alternative back refs to other objects
my $DECLARETYPE_RX = qr/(object|simple|table)/xms;
# Capture overall structure of autosql file
my $DECLARE_RX = qr/^\s* $DECLARETYPE_RX \s+ (\w+) \s+ \"(.+)\" \s+ \((.+)\)$/xms;

# Capture a single field
my $FIELD_RX = qr/
(?:
(?:$FIELDSTYPE_RX (?:$FIELDSIZE_RX|$FIELDVALUES_RX)?)
|
# Capture declarative backrefs e.g. object obj[objCount] or simple point[1]
(?: $DECLARETYPE_RX \s* ($NAME_RX) $FIELDSIZE_RX? )
)
\s*
($NAME_RX)
\s*
$INDEX_RX? $AUTO_RX?
;
\s*
$QUOTEDSTR_RX
/xms;

=pod

=head2 new($autosql)

Create a new object. Must give it an AutoSQL definition otherwise the library will throw an exception. The given string is also chomped.

=cut

sub new {
  my ($class, $autosql) = @_;
  confess("Parse error; no AutoSQL data given") if ! $autosql;
  chomp $autosql;
  my $self = bless({
    raw => $autosql,
    type => '',
    name => '',
    comment => '',
    fields => []
  }, (ref($class)||$class));
  $self->_parse();
  return $self;
}

=pod

=head2 raw()

Getter for the raw AutoSQL definition

=cut

sub raw {
  my ($self) = @_;
  return $self->{raw};
}

=pod

=head2 name()

Getter for the name found in this AutoSQL definition

=cut

sub name {
  my ($self) = @_;
  return $self->{name};
}

=pod

=head2 type()

Getter for the type found in this AutoSQL definition

=cut

sub type {
  my ($self) = @_;
  return $self->{type};
}

=pod

=head2 comment()

Getter for the comment found in this AutoSQL definition

=cut

sub comment {
  my ($self) = @_;
  return $self->{comment};
}

=pod

=head2 fields()

Access an array of L<Bio::DB::Big::AutoSQLField> objects parsed from the given AutoSQL definition

=cut

sub fields {
  my ($self) = @_;
  return $self->{fields};
}

=pod

=head2 get_field($name)

Returns a L<Bio::DB::Big::AutoSQLField> object for the given name. Returns undef if the field is unavailable.

=cut

sub get_field {
  my ($self, $field_name) = @_;
  return if ! $self->has_field($field_name);
  return $self->_field_lookup()->{$field_name};
}

=pod

=head2 has_field($name)

Return a boolean response if the given field is found in the parsed AutoSQL definition.

=cut

sub has_field {
  my ($self, $field_name) = @_;
  return exists $self->_field_lookup()->{$field_name} ? 1 : 0;
}

=pod

=head2 is_table() 

Returns a boolean if this AutoSQL object represents a table i.e. the type is set to table

=cut

sub is_table {
  my ($self) = @_;
  my $type = $self->type();
  return ($type eq 'table') ? 1 : 0;
}

sub _field_lookup {
  my ($self) = @_;
  if(! $self->{_field_lookup}) {
    $self->{_field_lookup} = {
      map { $_->name, $_ }
      @{$self->{fields}}
    };
  }
  return $self->{_field_lookup};
}

sub _parse {
  my ($self) = @_;
  my $raw_fields = $self->_parse_header();
  $self->_parse_fields($raw_fields);
  return;
}


sub _parse_header {
  my ($self) = @_;
  if(my ($type, $name, $comment, $raw_fields) = $self->{raw} =~ $DECLARE_RX) {
    $self->{type} = $type;
    $self->{name} = $name;
    $self->{comment} = $comment;
    return $raw_fields;
  }
  confess 'Parse error; cannot parse AutoSQL provided';
}

sub _parse_fields {
  my ($self, $raw_fields) = @_;
  my $position = 1;
  while($raw_fields =~ /$FIELD_RX/g) {
    my ($type, $field_size, $field_values, $declare_type, $declare_name, $declare_size, $name, $index_type, $index_size, $auto, $comment) = 
      ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);
    if(! $type) {
      $type = $declare_type;
    }
    my @field_values_parsed;
    if($field_values) {
      @field_values_parsed = split /,\s*/, $field_values;
    }
    $field_size = "$field_size" if $field_size;
    $index_size = "$index_size" if $index_size;
    my $field = Bio::DB::Big::AutoSQLField->new({
      type => $type,
      name => $name,
      comment => $comment,
      position => $position,
      field_size => $field_size,
      field_values => \@field_values_parsed,
      declare_size => $declare_size,
      declare_name => $declare_name,
      index_type => $index_type,
      index_size => $index_size,
      auto => $auto,
    });
    push(@{$self->{fields}}, $field);
    $position++;
  }
  return;
}

=pod

=cut

1;