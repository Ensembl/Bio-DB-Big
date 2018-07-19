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

package Bio::DB::Big::PythonModuleGenerator;

=pod

=head1 NAME

Bio::DB::Big::PythonModuleGenerator

=head1 SYNOPSIS

  my $generator = Bio::DB::Big::PythonModuleGenerator->new('My::Root::Namespace', $autosql_string);
  my $module = $geneator->generate();
  $geneator->generate_to_file('/path/to/file.py');

=head1 DESCRIPTION

Generate a Python module from an AutoSQL definition. The generated module is very basic with accessors
for each field, an C<init()> method with named attributes listed in bed order.

The generated code also comes with a method for creating a list of attributes in bed order called C<tolist>.

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
	return 'py';
}

sub warning_line {
	my ($self) = @_;
	return $WARNING_LINE;
}

sub _template {
	my ($self) = @_;
	return <<'TMPL';
#### THIS MODULE WAS GENERATED FROM AN AUTOSQL DEFINITION on [% time %]

class [% name %](object):
    """
    A represention of the [% name %] BED format generated from AutoSQL on [% time %].

    Attributes
    ----------
    [% FOREACH f IN fields %]
    [% f.name %] : [% f.type %]
        [% f.comment %]
    [% END %]
    """

    def __init__(self[% FOREACH f IN fields -%], [% f.name %][% END -%]):
        """
        Generate and instance of a [% name %] class.

        Parameters
        ----------
        [%- FOREACH f IN fields %]
        [% f.name %] : [% f.type %]
        [%- END %]
        """
    [% FOREACH f IN fields -%]
    self.[% f.name %] = [% f.name %]
    [% END -%]

    def tolist(self):
        """Generate a list of the fields in the expected BED output order"""
        bed_fields = list()
        [% FOREACH f IN fields %]bed_fields.append(self.[% f.name %])
        [% END %]return bed_fields

    def size(self):
        """Return the size of the feature"""
        return self.chromEnd - self.chromStart

    @staticmethod
    def number_of_fields():
        """Return the number of fields in the given object"""
        return [% field_count %]

    @staticmethod
    def autosql_name():
        """Return the original name used for this AutoSQL definition"""
        return '[% name %]'

    @staticmethod
    def autosql():
        """Return the original raw AutoSQL definition (useful if generating BigBed files)"""
        return """[% raw_autosql %]"""

[%- IF generate_fully_closed_accessors -%]

    def fc_chromStart(self, start=None):
        """Gets and sets the start of this feature in fully closed (1-based) coordinates"""
        if start is not None:
            self.chromStart = start - 1
        return self.chromStart + 1

    def fc_chromEnd(self, end=None):
        """Gets and sets the end of this feature in fully closed (1-based) coordinates. This end is the same as chromEnd"""
        if end is not None:
            self.chromEnd = end
        return self.chromEnd

[% END -%]

TMPL
}

1;