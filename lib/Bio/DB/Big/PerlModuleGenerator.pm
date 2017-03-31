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

package Bio::DB::Big::PerlModuleGenerator;

=pod

=head1 NAME

Bio::DB::Big::PerlModuleGenerator

=head1 SYNOPSIS

  my $autosql = Bio::DB::Big::AutoSQL->new($autosql_string);
  my $generator = Bio::DB::Big::PerlModuleGenerator->new('My::Root::Namespace', $autosql);
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

my $WARNING_LINE = '########### CUSTOM CODE BELOW: Only insert custom code below this line #############';

=pod

=head new($namespace, $autosql, $additional_code)

Construct an object with a namespace and an autosql object. You can also give the module additional code to import in

=cut

sub new {
  my ($class, $namespace, $autosql, $additional_code) = @_;
  my $self = bless({
    namespace => $namespace,
    autosql => $autosql,
    additional_code => $additional_code
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

=head2 autosql()

Accessor for the autosql given to this object

=cut

sub autosql {
  my ($self, $autosql) = @_;
  $self->{autosql} = $autosql if defined $autosql;
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
  return $self->_generate();
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

# Generates the entire module

sub _generate {
  my ($self) = @_;
  my $package = $self->namespace();
  my $autosql = $self->autosql();
  my $name = $autosql->name();
  my $fields = $autosql->fields();
  
  my $new = $self->_generate_new_methods();
  my $accessors = q{};
  foreach my $field (@{$fields}) {
    $accessors .= $self->_generate_accessor($field);
  }
  my $emitters = $self->_generate_emitters();
  my $additional_code = $self->additional_code() || q{};
  my $warning_line = $self->warning_line();
  
  my $time = strftime('%FT%T%z', localtime);
  
  my $module = <<MODULE;
#### THIS MODULE WAS GENERATED FROM AN AUTOSQL DEFINITION on $time

package ${package}::${name};
use strict;
use warnings;
use Carp qw/confess/;
use Scalar::Util qw/reftype/;

$new
$accessors
$emitters

$warning_line
$additional_code
1;
MODULE
}

# Creates a new() method for the generated module and a new_from_bed()
sub _generate_new_methods {
  my ($self) = @_;
  my $new_methods = q{};
  $new_methods .= <<TMPL;
sub new {
  my (\$package) = \@_;
  my \$class = ref(\$package) || \$package;
  return bless({}, \$class);
}

TMPL

  my $fields = $self->autosql()->fields();
  my $field_count = scalar(@{$fields});
  $new_methods .= <<TMPL;
sub new_from_bed {
  my (\$package, \$bed_line) = \@_;
  confess "Bed error; Not given an array reference as a bedline" unless reftype(\$bed_line) eq 'ARRAY';
  confess "Bed error; Bed line given does not have the right number of elements" unless scalar(\@{\$bed_line}) == $field_count;
  my \$self = \$package->new();
TMPL

  foreach my $field (@{$fields}) {
    my $name = $field->name();
    my $position = $field->position();
    $position--; #get into array coords
    $new_methods .= <<TMPL;
  \$self->$name(\$bed_line->[$position]);
TMPL
  }

  $new_methods .= <<TMPL;
  return \$self;
}
TMPL
  return $new_methods;
}

sub _generate_emitters {
  my ($self) = @_;
  my $emitters = q{};
  my $fields = $self->autosql()->fields();
  $emitters .= <<TMPL;
=pod

=head2 to_array

Create an array of elements. These will be ordered as the fields appeared in the input BED

=cut

sub to_array {
  my (\$self) = \@_;
  return [
TMPL
  foreach my $field (@{$fields}) {
    my $name = $field->name();
    $emitters.= "    \$self->$name(),\n";
  }
  $emitters .= <<TMPL;
  ];
}

=pod

=head2 to_hash

Returns a hash copy of the fields

=cut

sub to_hash {
  my (\$self) = \@_;
  return { %{ \$self }};
}
TMPL
}

# Takes in an autosql field and creates an accessor to be used
sub _generate_accessor {
  my ($self, $field) = @_;
  my $name = $field->name();
  my $routine = <<TMPL;
=pod 

=head2 $name

Accessor for the attribute $name

=cut

sub $name {
  my (\$self, \$${name}) = \@_;
  \$self->{'${name}'} = \$${name} if defined \$${name};
  return \$self->{'${name}'};
}
TMPL
  return $routine;
}

1;