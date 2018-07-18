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

use strict;
use warnings;

use Test::More;
use Test::Exception;

use File::Temp qw/tempfile/;

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
my $additional_code = 'sub tmp { return "MOD";}';
my $generate_fc_accessors = 1;
my $generator = Bio::DB::Big::PerlModuleGenerator->new('Tmp::Namespace', $raw_autosql, $additional_code, $generate_fc_accessors);
my $module = $generator->generate();
note $module;

my (undef, $tmp_filename) = tempfile('TMPPERL.XXXXXXX', OPEN => 0, TMPDIR => 1);
$generator->generate_to_file($tmp_filename);
ok(-f $tmp_filename, 'Checking file is on disk');
ok(-s $tmp_filename, 'File has content');
my $written_module = q{};
{
  local $/ = undef;
  open my $fh, '<', $tmp_filename or die "Cannot open '$tmp_filename' for reading: $!";
  $written_module = <$fh>;
  close $fh;
  unlink $tmp_filename;
}
is($written_module, $module, 'Making sure the written file and generated output are the same');

ok($module, 'Checking we got content back');
eval $module; # attempt to bring it in
my $error = $@;
if($error) {
  note $error;
  BAIL_OUT('Generated module did not compile. Cannot use. Check the generator module as it is no longer creating valid Perl');
}

my $bed_array = ['chr1', 1, 10, 'name', 0, '+'];
my $bed6 = Tmp::Namespace::bed6->new_from_bed($bed_array);
is($bed6->chrom(), 'chr1', 'Checking chrom accessor works as expected');
is($bed6->chromStart(), 1, 'Checking chromStart accessor works as expected');
is($bed6->fc_chromStart(), 2, 'Checking fc_chromStart returns back in 1-based coordinates');
is($bed6->fc_chromEnd(), 10, 'Checking fc_chromEnd returns back in 1-based coordinates');
is($bed6->size(), 9, 'Making sure length calculation works');
is($bed6->chromEnd(), 10, 'Checking chromEnd accessor works as expected');
is($bed6->name(), 'name', 'Checking name accessor works as expected');
is($bed6->score(), 0, 'Checking score accessor works as expected');
is($bed6->strand(), '+', 'Checking strand accessor works as expected');

is_deeply($bed6->to_array(), $bed_array, 'Checking output from to_array matches input');
my $hash = $bed6->to_hash();
is($hash->{chrom}, 'chr1', 'Checking output to hash has expected chrom value');
is(scalar(keys %{$hash}), 6, 'Checking hash has 6 elements');

is($bed6->tmp(), 'MOD', 'Checking injected code can be called');

throws_ok { Tmp::Namespace::bed6->new_from_bed({}) } qr/Bed error.+array ref.+/, 'Building with a hash does not work';
throws_ok { Tmp::Namespace::bed6->new_from_bed(['chr1', 1, 10]) } qr/Bed error.+right number of elements.+/, 'Building with an array with too few elements does not work';

my $newbed = Tmp::Namespace::bed6->new();
$newbed->fc_chromStart(2);
$newbed->fc_chromEnd(10);
is($newbed->chromStart(), 1, 'Checking chromStart set works');
is($newbed->fc_chromStart(), 2, 'Checking fc_chromStart set works');
is($newbed->chromEnd(), 10, 'Checking chromEnd set works');
is($newbed->fc_chromEnd(), 10, 'Checking fc_chromEnd set works');

done_testing();
