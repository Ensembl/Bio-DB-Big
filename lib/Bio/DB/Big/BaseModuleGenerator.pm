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
package Bio::DB::Big::BaseModuleGenerator;

=pod

=head1 NAME

Bio::DB::Big::BaseModuleGenerator

=head1 DESCRIPTION

Base class for use in generating modules.

=head1 METHODS

=cut

use strict;
use warnings;
use POSIX qw/strftime/;
use Template::Tiny;
use Carp qw/confess/;
use Bio::DB::Big::AutoSQL;

sub extension {
  confess('Implement this method');
}

sub _template {
	confess('Implement this method');
}

sub warning_line {
  my ($self) = @_;
  confess('Implement this method');
}

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



1;