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

=head1 METHODS

=cut

use strict;
use warnings;

=pod

=head new($namespace, $autosql)

Construct an object with a namespace and an autosql object

=cut

sub new {
  my ($class, $namespace, $autosql) = @_;
  my $self = bless({
    namespace => $namespace,
    autosql => $autosql,
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
  
  my $module = <<MODULE;
#### THIS MODULE WAS GENERATED FROM AN AUTOSQL DEFINITION. DO NOT UPDATE MANUALLY

package ${package}::${name};
use strict;
use warnings;
use Carp qw/confess/;
use Scalar::Util qw/reftype/;

$new
$accessors
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