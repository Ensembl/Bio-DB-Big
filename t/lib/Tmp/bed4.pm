#### THIS MODULE WAS GENERATED FROM AN AUTOSQL DEFINITION on 2018-07-09T18:10:54+0100

package Tmp::bed4;

use strict;
use warnings;
use Carp qw/confess/;
use Scalar::Util qw/reftype/;

=pod

=head2 new

    my $obj = Namespace::bed4->new();

Create an empty blessed instance of this class. Useful to use when generating BED lines.

=cut

sub new {
  my ($package) = @_;
  my $class = ref($package) || $package;
  return bless({}, $class);
}

=pod

=head2 new_from_bed

    my $obj = Namespace::bed4->new_from_bed(['chr1', 0, 1, 'id' ]);

Create an instance of this package by giving the constructor an array representing a single bed line. The code
will error if the item given is not an array or does not match the expected number of fields.

=cut

sub new_from_bed {
  my ($package, $bed_line) = @_;
  confess "Bed error; Not given an array reference as a bedline" unless reftype($bed_line) eq 'ARRAY';
  confess "Bed error; Bed line given does not have the right number of elements" unless scalar(@{$bed_line}) == 4;
  my $self = $package->new();
  $self->chrom($bed_line->[0]);
  $self->chromStart($bed_line->[1]);
  $self->chromEnd($bed_line->[2]);
  $self->name($bed_line->[3]);
  return $self;
}

=pod

=head2 to_array

Create an array of elements. These will be ordered as the fields appeared in the input BED

=cut

sub to_array {
  my ($self) = @_;
  return [
    $self->chrom(),
    $self->chromStart(),
    $self->chromEnd(),
    $self->name(),
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
=pod

=head2 chrom

Accessor for the attribute chrom

=cut

sub chrom {
  my ($self, $chrom) = @_;
  $self->{'chrom'} = $chrom if defined $chrom;
  return $self->{'chrom'};
}
=pod

=head2 chromStart

Accessor for the attribute chromStart

=cut

sub chromStart {
  my ($self, $chromStart) = @_;
  $self->{'chromStart'} = $chromStart if defined $chromStart;
  return $self->{'chromStart'};
}
=pod

=head2 chromEnd

Accessor for the attribute chromEnd

=cut

sub chromEnd {
  my ($self, $chromEnd) = @_;
  $self->{'chromEnd'} = $chromEnd if defined $chromEnd;
  return $self->{'chromEnd'};
}
=pod

=head2 name

Accessor for the attribute name

=cut

sub name {
  my ($self, $name) = @_;
  $self->{'name'} = $name if defined $name;
  return $self->{'name'};
}

=pod

=head2 size

Returns the size of this BED feature. Just does a chromEnd - chromStart

=cut

sub size {
  my ($self) = @_;
  return $self->chromEnd() - $self->chromStart();
}

########### CUSTOM CODE BELOW: Only insert custom code below this line #############

sub size_times_two {
  my ($self) = @_;
  return $self->size()*2;
}

1;
__END__
# AutoSQL used to generate this class
table bed4
"bed4 format"
    (
    string chrom;       "Reference sequence chromosome or scaffold"
    uint   chromStart;  "Start position in chromosome"
    uint   chromEnd;    "End position in chromosome"
    string name;        "Name or ID of item, ideally both human readable and unique"
    )

