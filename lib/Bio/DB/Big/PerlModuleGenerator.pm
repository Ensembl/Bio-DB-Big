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
use POSIX qw/strftime/;
use Template::Tiny;
use Carp qw/confess/;
use Bio::DB::Big::AutoSQL;

my $WARNING_LINE = '########### CUSTOM CODE BELOW: Only insert custom code below this line #############';

=pod

=head new($namespace, $raw_autosql, $additional_code, generate_fully_closed_accessors)

Construct an object with a namespace and an autosql object. You can also give the module additional code to import
into the module and an option to generate fully closed (Ensembl style) coordinate accessors

=cut

sub new {
  my ($class, $namespace, $raw_autosql, $additional_code, $generate_fully_closed_accessors) = @_;
  confess "No namespace given" unless defined $namespace;
  confess "No raw AutoSQL given" unless defined $raw_autosql;
  my $self = bless({
    namespace => $namespace,
    raw_autosql => $raw_autosql,
    additional_code => $additional_code,
    generate_fully_closed_accessors => $generate_fully_closed_accessors
  }, (ref($class)||$class));
  return $self;
}

=pod

=head2 namespace()

Accessor for the namespace given to this object

=cut

sub namespace {
  my ($self, $namespace) = @_;
  $self->{namespace} = $namespace if defined $namespace;
  return $self->{namespace};
}

=pod

=head2 raw_autosql()

Accessor for the raw_autosql given to this object

=cut

sub raw_autosql {
  my ($self, $raw_autosql) = @_;
  $self->{raw_autosql} = $raw_autosql if defined $raw_autosql;
  return $self->{raw_autosql};
}

=head2 autosql()

Accessor for the autosql given to this object or lazy loaded from the raw_autosql

=cut

sub autosql {
  my ($self, $autosql) = @_;
  $self->{autosql} = $autosql if defined $autosql;
  if(! defined $self->{autosql}) {
    $self->{autosql} = Bio::DB::Big::AutoSQL->new($self->{raw_autosql});
  }
  return $self->{autosql};
}

=pod

=head2 additional_code()

Accessor for the additional_code given to this object. This is custom additional code to be injected
into the class

=cut

sub additional_code {
  my ($self, $additional_code) = @_;
  $self->{additional_code} = $additional_code if defined $additional_code;
  return $self->{additional_code};
}

=pod

=head2 generate_fully_closed_accessors()

If set to true we will generate two accessors called C<fc_chromStart> and C<fc_chromEnd>, which handle
converting between 0-start and 1-start coordinate systems. We assume all BED files have these
fields filled in.

=cut

sub generate_fully_closed_accessors {
  my ($self, $generate_fully_closed_accessors) = @_;
  $self->{generate_fully_closed_accessors} = $generate_fully_closed_accessors if defined $generate_fully_closed_accessors;
  return $self->{generate_fully_closed_accessors};
}

=pod

=head2 warning_line

Emit the warning line used to denote custom code in a generated module

=cut

sub warning_line {
  my ($self) = @_;
  return $WARNING_LINE;
}

=pod

=head2 generate()

Creates the module and returns it as a scalar

=cut

sub generate {
  my ($self) = @_;
  return $self->_generate_tt();
}

=pod

=head2 generate_to_file($file)

Generates the module and writes it to the specified location

=cut

sub generate_to_file {
  my ($self, $file) = @_;
  my $module = $self->generate();
  open my $fh, '>', $file or die "Cannot open '$file' for writing: $!";
  print $fh $module;
  close $fh or die "Cannot close '$file': $!";
  return 1;
}

# Grabs the params, formats, grabs the template, runs template tiny and returns the output
sub _generate_tt {
  my ($self) = @_;
  my $template = $self->_template();
  my $autosql = $self->autosql();

  my $fields = [
    map { { name => $_->name(), index => ($_->position()-1), comment => $_->comment(), type => $_->type() } }
    @{$autosql->fields()}
  ];

  my $params = {
    name => $autosql->name(),
    raw_autosql => $self->raw_autosql(),
    fields => $fields,
    field_count => scalar(@{$fields}),
    time => strftime('%FT%T%z', localtime),
    namespace => $self->namespace(),
    warning_line => $self->warning_line(),
    additional_code => $self->additional_code(),
    generate_fully_closed_accessors => $self->generate_fully_closed_accessors(),
  };

  my $output = q{};
  my $tt = Template::Tiny->new(TRIM => 0);
  $tt->process(\$template, $params, \$output);
  return $output;
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

    my $obj = [%namespace %]::[%name %]->new_from_bed([ ... ]);

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
__END__
# AutoSQL used to generate this class
[% raw_autosql %]
TMPL
}

1;