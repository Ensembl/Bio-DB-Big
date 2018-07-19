=head1 LICENSE

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
package Bio::DB::Big::PerlModuleGenerator;

=pod

=head1 NAME

Bio::DB::Big::PerlModuleGenerator

=head1 SYNOPSIS

  my $generator = Bio::DB::Big::PerlModuleGenerator->new('My::Root::Namespace', $autosql_string);
  my $module = $geneator->generate();
  $geneator->generate_to_file('/path/to/file.pm');

=head1 DESCRIPTION

Generate a Perl module from an AutoSQL definition. The generated module is very basic with accessors
for each field available, a C<new()> method and a C<new_from_bed()> method that can be used
to construct an object from an array of bed elements. C<new_from_bed()> will error if an array is not
given or the given array does not have the correct number of elements.

The generated code also comes with two methods for creating new data structures. C<to_array>, which
creates an array ordered as a BED line would be. The second is C<to_hash>, which is a hash copy of the object.

=head1 METHODS

=cut

use strict;
use warnings;
use base qw/Bio::DB::Big::BaseModuleGenerator/;

use POSIX qw/strftime/;
use Template::Tiny;
use Carp qw/confess/;
use Bio::DB::Big::AutoSQL;


my $WARNING_LINE = '########### CUSTOM CODE BELOW: Only insert custom code below this line #############';

sub extension {
  return 'pm';
}

sub warning_line {
	my ($self) = @_;
	return $WARNING_LINE;
}

# Return the template. Originally did this by reading <DATA> and having it as a __DATA__ block. That didn't work on rereads
sub _template {
  my ($self) = @_;
  return <<'TMPL';
#### THIS MODULE WAS GENERATED FROM AN AUTOSQL DEFINITION on [% time %]

package [% namespace %]::[% name %];

use strict;
use warnings;
use Carp qw/confess/;
use Scalar::Util qw/reftype/;

=pod

=head2 new

    my $obj = [%namespace %]::[%name %]->new();

Create an empty blessed instance of this class. Useful to use when generating BED lines.

=cut

sub new {
  my ($package) = @_;
  my $class = ref($package) || $package;
  return bless({}, $class);
}

=pod

=head2 new_from_bed

    my $obj = [% namespace %]::[% name %]->new_from_bed([ ... ]);

Create an instance of this package by giving the constructor an array representing a single bed line. The code
will error if the item given is not an array or does not match the expected number of fields.

=cut

sub new_from_bed {
  my ($package, $bed_line) = @_;
  confess "Bed error; Not given an array reference as a bedline" unless reftype($bed_line) eq 'ARRAY';
  confess "Bed error; Bed line given does not have the right number of elements" unless scalar(@{$bed_line}) == [% field_count %];
  my $self = $package->new();
  [% FOREACH f IN fields -%]
$self->[% f.name %]($bed_line->[[% f.index %]]);
  [% END -%]
return $self;
}

=pod

=head2 to_array

Create an array of elements. These will be ordered as the fields appeared in the input BED

=cut

sub to_array {
  my ($self) = @_;
  return [
  [% FOREACH f IN fields -%]
  $self->[% f.name %](),
  [% END -%]
];
}

=pod

=head2 to_hash

Returns a hash copy of the fields

=cut

sub to_hash {
  my ($self) = @_;
  return { %{ $self }};
}

=head2 autosql

Returns the original AutoSQL definition used to generate this class

=cut

sub autosql {
  my ($self) = @_;
  return qq{[% autosql %]};
}

=head2 autosql_name

Returns the original AutoSQL name (should be the same as the class)

=cut

sub autosql_name {
  my ($self) = @_;
  return '[% name %]';
}

=head2 number_of_fields

Returns the total number of fields in this AutoSQL file

=cut

sub number_of_fields {
  my ($self) = @_;
  return [% fields_count %];
}

[%- FOREACH f IN fields -%]
=pod

=head2 [% f.name %]

Accessor for the attribute [% f.name %] ([% f.type %]). [% f.comment %]

=cut

sub [% f.name %] {
  my ($self, $[% f.name %]) = @_;
  $self->{'[% f.name %]'} = $[% f.name %] if defined $[% f.name %];
  return $self->{'[% f.name %]'};
}

[%- END -%]

=pod

=head2 size

Returns the size of this BED feature. Just does a chromEnd - chromStart

=cut

sub size {
  my ($self) = @_;
  return $self->chromEnd() - $self->chromStart();
}

[%- IF generate_fully_closed_accessors -%]
=pod

=head2 fc_chromStart

Accessor for coordinates of this BED feature in 1-start, fully-closed coordinates. This means adding +1 to the start. You can give this method a coordinate in 1-start and it will convert it back to 0-start.

=cut

sub fc_chromStart {
  my ($self, $fc_chromStart) = @_;
  if(defined $fc_chromStart) {
    $self->chromStart($fc_chromStart-1);
  }
  return $self->chromStart()+1;
}

=pod

=head2 fc_chromEnd

Accessor for coordinates of this BED feature in 1-start, fully-closed coordinates. This means returning the end. You can set chromEnd via this method

=cut

sub fc_chromEnd {
  my ($self, $fc_chromEnd) = @_;
  if(defined $fc_chromEnd) {
    $self->chromEnd($fc_chromEnd);
  }
  return $self->chromEnd();
}
[% END -%]

[% warning_line %]

[%- IF additional_code -%]
[% additional_code %]
[% END -%]

1;
TMPL
}

1;