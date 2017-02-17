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

package Bio::DB::Big::AutoSQLField;

=pod

=head1 NAME

Bio::DB::Big::AutoSQLField

=head1 SYNOPSIS

  printf("%d: %s (%s)\n", $field->position(), $field->name(), $field->type());

=head1 DESCRIPTION

Provides access to an AutoSQL field's definition

=head1 METHODS

=cut

use strict;
use warnings;

sub new {
  my ($class, $hash) = @_;
  my $self = bless({%{$hash}}, (ref($class)||$class));
  return $self;
}

=pod

=head2 type()

Accessor for the type of field this is. Can be one of the following items.

=over 8

=item int

=item uint

=item short

=item ushort

=item byte

=item ubyte

=item float

=item char

=item string

=item lstring

=item enum

=item set

=back

In addition we can have a field set to object, simple or table. These are normally used to backreference another AutoSQL definition. If you field is set to one of these consult C<declare_name>, C<declare_size>.

=cut

sub type {
  my ($self) = @_;
  return $self->{type};
}

=pod

=head2 name()

Accessor for the name given to this field.

=cut

sub name {
  my ($self, $name) = @_;
  $self->{name} = $name if defined $name;
  return $self->{name};
}

=pod

=head2 comment()

Accessor for the comment given to this field. 

=cut

sub comment {
  my ($self, $comment) = @_;
  $self->{comment} = $comment if defined $comment;
  return $self->{comment};
}

=pod

=head2 position()

Accessor for the position this field occupies in the AutoSQL definition. This is indexed from 1 and maps to BigBed column positions. 

=cut

sub position {
  my ($self, $position) = @_;
  $self->{position} = $position if defined $position;
  return $self->{position};
}

=pod

=head2 field_size()

Accessor for the field size assigned to this field. This is normally used when a fixed length char has been specified e.g.

   char[2] state index;  "Just store the abbreviation for the state"

=cut

sub field_size {
  my ($self, $field_size) = @_;
  $self->{field_size} = $field_size if defined $field_size;
  return $self->{field_size};
}

=pod

=head2 field_values()

Accessor for the field values. Only used if the field was an enum or set. Values are presented in the parsed order but no additional meaning is given.

=cut

sub field_values {
  my ($self, $field_values) = @_;
  $self->{field_values} = $field_values if defined $field_values;
  return $self->{field_values};
}

=pod

=head2 declare_name()

Accessor for the declared name. Used when field type was set to simple, object or table. This should be set to the back-referened AutoSQL name e.g.

  object face[faceCount] faces; "List of faces"

Here declare name would be set to face where we expect to find the definition of the face object.

=cut

sub declare_name {
  my ($self, $declare_name) = @_;
  $self->{declare_name} = $declare_name if defined $declare_name;
  return $self->{declare_name};
}

=pod

=head2 declare_size()

Accessor for the declare size i.e. the number of elements available. If set to a number this is a fixed size. If this is a string then it points to a field in the AutoSQL definition that should be used to set the field size e.g.

  object face[faceCount] faces; "List of faces"

Here declare size is set to C<faceCount>.

=cut

sub declare_size {
  my ($self, $declare_size) = @_;
  $self->{declare_size} = $declare_size if defined $declare_size;
  return $self->{declare_size};
}

=pod

=head2 index_type()

Accessor for the type of index for a field. Can be set to primary, index or unique.

=cut

sub index_type {
  my ($self, $index_type) = @_;
  $self->{index_type} = $index_type if defined $index_type;
  return $self->{index_type};
}

=pod

=head2 index_size()

Accessor for the size of index to generate. Used in definitions to create a prefix index e.g.

  string city index[12];  "City - indexing just first 12 character"

This would create an index on the city field where the first 12 characters were used in the index.

=cut

sub index_size {
  my ($self, $index_size) = @_;
  $self->{index_size} = $index_size if defined $index_size;
  return $self->{index_size};
}

=pod

=head2 auto()

Accessor for the auto field. Flags if this field is considered an auto incremented key e.g.

  uint id primary auto; "Autoincrementing primary key for this record."

There is nothing more than to note it is an autoincrementing key

=cut

sub auto {
  my ($self, $auto) = @_;
  $self->{auto} = $auto if defined $auto;
  return $self->{auto};
}

1;