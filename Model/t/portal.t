use strict;
use warnings;
use Test::More tests => 19;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Portal;

my $P = 'ApiCommonModel::Model::ApolloRelease::Portal';

# A synthetic organism carries filler that no test is about.  Defaulting it
# here leaves each case showing only the fields it actually exercises.
sub _org {
  my (%overrides) = @_;
  return { name                => 'x',
           name_for_filenames  => 'x',
           strain_abbrev       => 'x',
           species_ncbi_tax_id => '1',
           is_reference_strain => '1',
           is_annotated_genome => '1',
           history             => [],
           %overrides };
}

my $orgs = $P->loadFromFile("Model/t/fixtures/portal.json");

is(ref($orgs), 'HASH', 'returns a hash keyed by abbrev');
ok(exists $orgs->{tgonME49}, 'tgonME49 present');

my $t = $orgs->{tgonME49};
is($t->{abbrev}, 'tgonME49', 'abbrev normalised');
is($t->{name_for_filenames}, 'TgondiiME49', 'name_for_filenames carried');
is($t->{is_reference}, 1, 'is_reference is a boolean, not a string');
is($t->{is_annotated}, 1, 'is_annotated is a boolean, not a string');

my $b = $orgs->{tbruLister427_2018};
is($b->{is_reference}, 0, 'non-reference strain is 0');

ok(defined $t->{latest_annotation_version}, 'latest annotation version derived');
is($P->qualifies($b), 0, 'non-reference organism does not qualify');

# "0.0" is truthy as a Perl string but zero numerically.  Pin the coercion so a
# future upstream change to the flag's format cannot silently invert it.
my $synthetic = $P->normalise({organisms => [
  _org(organism_abbrev => 'zeroPointZero', is_reference_strain => '0.0',
       history => [{build_number => '9',    annotation_version => 'older'},
                   {build_number => '19.9', annotation_version => 'middle'},
                   {build_number => '71',   annotation_version => 'newest'}]),
]});
is($synthetic->{zeroPointZero}{is_reference}, 0, '"0.0" normalises to false, not true');
is($synthetic->{zeroPointZero}{latest_annotation_version}, 'newest',
   'highest build number wins numerically: beats lexically-larger "9" and a decimal');

eval { $P->normalise({organisms => [
  _org(organism_abbrev => 'bogus', is_reference_strain => 'yes'),
]}) };
like($@, qr/expected a numeric flag/, 'a non-numeric flag is a hard error, not a guess');

# A non-numeric build_number is skipped deliberately rather than left to Perl's
# numeric comparison.
#
# Both organisms are needed to pin the skip.  messyBuilds shows a bad row does
# not corrupt the ordering of the good rows around it -- but that alone would
# pass even with the guard deleted, because "not-a-number" + 0 is 0 and any
# real build number beats it.  onlyBad is the discriminating case: with the
# guard the row is skipped and there is no latest version; without it the row
# becomes $best by default and 'bogus' is returned as the annotation version.
my $messy = $P->normalise({organisms => [
  _org(organism_abbrev => 'messyBuilds',
       history => [{build_number => 'not-a-number', annotation_version => 'bogus'},
                   {build_number => '9',            annotation_version => 'older'},
                   {build_number => '71',           annotation_version => 'newest'}]),
  _org(organism_abbrev => 'onlyBad',
       history => [{build_number => 'not-a-number', annotation_version => 'bogus'}]),
]});
is(join('|', map { $messy->{$_}{latest_annotation_version} // 'undef' } qw(messyBuilds onlyBad)),
   'newest|undef',
   'a non-numeric build_number is skipped: it neither wins nor disturbs the good rows');

# A skip stays REPORTABLE, it just does not go to stderr -- this module's own
# loadFromCommand treats a child's stderr byte as fatal, so warning that way
# would make a handled skip look like a release-breaking error to a caller
# applying the same rule to us.
$P->normalise({organisms => [
  _org(organism_abbrev => 'messyBuilds',
       history => [{build_number => 'not-a-number', annotation_version => 'bogus'}]),
]});
my @skipWarnings = $P->warnings;
is(scalar(@skipWarnings), 1, 'warnings are reset per normalise call, not accumulated');
like($skipWarnings[0], qr/messyBuilds.*non-numeric build_number 'not-a-number'/,
     'the collected warning names the organism it concerns');

$P->loadFromFile("Model/t/fixtures/portal.json");
is(scalar($P->warnings), 0, 'a clean document collects no warnings');

# Asymmetry with the die-on-garbage path above is deliberate: a NULL flag is
# plausible upstream and must not stop a release over one row.
my $missing = $P->normalise({organisms => [
  _org(organism_abbrev => 'noFlag', is_reference_strain => undef),
]});
is($missing->{noFlag}{is_reference}, 0, 'a missing flag reads as false rather than dying');
like(join("\n", $P->warnings), qr/noFlag: is_reference_strain is missing/,
     'a missing flag is still reported, naming the organism and the field');

eval { $P->normalise({organisms => [
  _org(organism_abbrev => 'dupe'),
  _org(organism_abbrev => 'dupe'),
]}) };
like($@, qr/duplicate organism_abbrev 'dupe'/,
     'a duplicate abbrev dies rather than silently discarding an organism');
