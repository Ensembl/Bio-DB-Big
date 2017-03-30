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

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Bio::DB::Big::AutoSQL;
use Bio::DB::Big::PerlModuleGenerator;

my $raw_autosql = qq{table bed6
"Browser extensible data"
    (
    string chrom;      "Reference sequence chromosome or scaffold"
    uint   chromStart; "Start position in chromosome"
    uint   chromEnd;   "End position in chromosome"
    string name;       "Name of item"
    uint   score;      "Score from 0-1000"
    char[1] strand;    "+ or -"
    )};
my $autosql = Bio::DB::Big::AutoSQL->new($raw_autosql);
my $generator = Bio::DB::Big::PerlModuleGenerator->new('Tmp::Namespace', $autosql);
my $module = $generator->generate();
diag $module;

ok($module, 'Checking we got content back');
eval $module; # attempt to bring it in
my $error = $@;
diag $error;
BAIL_OUT('Generated module did not compile. Cannot use') if $error;

my $bed6 = Tmp::Namespace::bed6->new_from_bed(['chr1', 1, 10, 'name', 0, '+']);
is($bed6->chrom(), 'chr1', 'Checking chrom accessor works as expected');
is($bed6->chromStart(), 1, 'Checking chromStart accessor works as expected');
is($bed6->chromEnd(), 10, 'Checking chromEnd accessor works as expected');
is($bed6->name(), 'name', 'Checking name accessor works as expected');
is($bed6->score(), 0, 'Checking score accessor works as expected');
is($bed6->strand(), '+', 'Checking strand accessor works as expected');

throws_ok { Tmp::Namespace::bed6->new_from_bed({}) } qr/Bed error.+array ref.+/, 'Building with a hash does not work';
throws_ok { Tmp::Namespace::bed6->new_from_bed(['chr1', 1, 10]) } qr/Bed error.+right number of elements.+/, 'Building with an array with too few elements does not work';

done_testing();
