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

package Bio::DB::Big::GeneratorExe;
use strict;
use warnings;

use Carp qw/confess/;
use HTTP::Tiny;
use English qw/-no_match_vars/;
use File::Spec;

use Bio::DB::Big::PerlModuleGenerator;
use Bio::DB::Big::PythonModuleGenerator;

my $language_to_generator = {
  perl => 'Bio::DB::Big::PerlModuleGenerator',
  python => 'Bio::DB::Big::PythonModuleGenerator',
};

sub language_to_generator {
  my ($class, $language) = @_;
  if(exists $language_to_generator->{$language}) {
    return $language_to_generator->{$language};
  }
  confess "Cannot decode $language to a suitable module generator";
}

# Use this to generate multiple files of AutoSQL perl module goodness!
sub builder {
  my ($class, $namespace, $autosql, $target, $generate_fully_closed_accessors, $language) = @_;
  my @generators;
  if(-d $autosql) {
    confess "Both -autosql ($autosql) and -target ($target) must be directories if one is a directory" if ! -d $target;
    opendir(my $dh, $autosql) or confess "Cannot open $autosql directory for reading: $!";
    my $ext = $class->language_to_generator($language)->extension();
    while (my $file = readdir($dh)) {
      next if ($file =~ m/^\./);
      next if ($file =~ m/^\.\./);
      next if ($file !~ m/\.as$/);
      my $autosql_location = File::Spec->catfile($autosql, $file);
      my $module_name = $file;
      $module_name =~ s/\.as$/.$ext/;
      my $target_file = File::Spec->catfile($target, $module_name);
      push(@generators, $class->new($namespace, $autosql_location, $target_file, $generate_fully_closed_accessors, $language));
    }
  }
  else {
    push(@generators, $class->new($namespace, $autosql, $target, $generate_fully_closed_accessors, $language));
  }
  return \@generators;
}

sub new {
  my ($class, $namespace, $autosql_location, $target_file, $generate_fully_closed_accessors, $language) = @_;
  confess "No namespace given" unless defined $namespace;
  confess "No AutoSQL location given" unless defined $autosql_location;
  confess "AutoSQL file not found at location ${autosql_location}" if ($autosql_location !~ /\w+:\/\// && ! -f $autosql_location);
  confess "No target file location given" unless defined $target_file;
  confess "No language known about $language" unless exists $language_to_generator->{$language};

  my $self = bless({
    namespace => $namespace,
    autosql_location => $autosql_location,
    target_file => $target_file,
    generate_fully_closed_accessors => $generate_fully_closed_accessors,
    language => $language
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

=head2 autosql_location()

Accessor for the autosql location given to this object

=cut

sub autosql_location {
  my ($self, $autosql_location) = @_;
  $self->{autosql_location} = $autosql_location if defined $autosql_location;
  return $self->{autosql_location};
}

=head2 target_file()

Accessor for the target file location given to this object

=cut

sub target_file {
  my ($self, $target_file) = @_;
  $self->{target_file} = $target_file if defined $target_file;
  return $self->{target_file};
}

=head2 language()

Accessor for the language generator

=cut

sub language {
  my ($self, $language) = @_;
  $self->{language} = $language if defined $language;
  return $self->{language};
}

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

=head2 run()

Run the generator code. Will execute with all given options.

=cut

sub run {
  my ($self) = @_;
  my $raw_autosql = $self->_slurp($self->autosql_location);
  my $additional_code = $self->get_additional_code_block();
  my $generator = $self->language_to_generator($self->language())->new($self->namespace(), $raw_autosql, $additional_code, $self->generate_fully_closed_accessors());
  $generator->generate_to_file($self->target_file());
  return;
}

sub get_additional_code_block {
  my ($self) = @_;
  my $target_file = $self->target_file();
  return q{} if ! -f $target_file;
  my $module = $self->_slurp($target_file);
  open my $fh, '<', \$module or confess "Could not read string: $!";
  my $capture = 0;
  my $code = q{};
  while(my $line = <$fh>) {
    if($line =~ /^1;/) {
      $capture = 0;
    }
    if($capture) {
      $code .= $line;
    }
    if($line =~ /^########### CUSTOM CODE BELOW/) {
      $capture = 1;
    }
  }
  chomp($code);
  chomp($code);
  return $code;
}

sub _slurp {
  my ($self, $location) = @_;
  # Search for word://.... e.g. https:// which means it is a URL so redirect to that
  if($location =~ /^\w+:\/\//) {
    return $self->_grab_from_url($location);
  }
  local $/ = undef;
  open my $fh, '<', $location or confess "Cannot open $location for reading: $!";
  my $content = <$fh>;
  close $fh or confess "Cannot close $location file handle: $!";
  return $content;
}

# Only execute if we were given a URL!
sub _grab_from_url {
  my ($self, $location) = @_;
  my $response = HTTP::Tiny->new->get($location);
  confess("Cannot get AutoSQL from $location: ".$response->{reason}) if ! $response->{success};
  return $response->{content};
}

1;
