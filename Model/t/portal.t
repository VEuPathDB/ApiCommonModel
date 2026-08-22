use strict;
use warnings;
use Test::More tests => 13;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Portal;

my $P = 'ApiCommonModel::Model::ApolloRelease::Portal';

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
  {organism_abbrev => 'zeroPointZero', is_reference_strain => '0.0', is_annotated_genome => '1',
   name => 'x', name_for_filenames => 'x', strain_abbrev => 'x', species_ncbi_tax_id => '1',
   history => [{build_number => '9',    annotation_version => 'older'},
               {build_number => '19.9', annotation_version => 'middle'},
               {build_number => '71',   annotation_version => 'newest'}]},
]});
is($synthetic->{zeroPointZero}{is_reference}, 0, '"0.0" normalises to false, not true');
is($synthetic->{zeroPointZero}{latest_annotation_version}, 'newest',
   'highest build number wins numerically: beats lexically-larger "9" and a decimal');

eval { $P->normalise({organisms => [
  {organism_abbrev => 'bogus', is_reference_strain => 'yes', is_annotated_genome => '1', history => []},
]}) };
like($@, qr/expected a numeric flag/, 'a non-numeric flag is a hard error, not a guess');

# A non-numeric build_number is skipped deliberately, with our own warning --
# not left to Perl's numeric comparison, whose "isn't numeric" warning would
# go to stderr, which loadFromCommand treats as fatal.
#
# Both organisms are needed to pin the skip.  messyBuilds shows a bad row does
# not corrupt the ordering of the good rows around it -- but that alone would
# pass even with the guard deleted, because "not-a-number" + 0 is 0 and any
# real build number beats it.  onlyBad is the discriminating case: with the
# guard the row is skipped and there is no latest version; without it the row
# becomes $best by default and 'bogus' is returned as the annotation version.
my $messy = $P->normalise({organisms => [
  {organism_abbrev => 'messyBuilds', is_reference_strain => '1', is_annotated_genome => '1',
   name => 'x', name_for_filenames => 'x', strain_abbrev => 'x', species_ncbi_tax_id => '1',
   history => [{build_number => 'not-a-number', annotation_version => 'bogus'},
               {build_number => '9',            annotation_version => 'older'},
               {build_number => '71',           annotation_version => 'newest'}]},
  {organism_abbrev => 'onlyBad', is_reference_strain => '1', is_annotated_genome => '1',
   name => 'x', name_for_filenames => 'x', strain_abbrev => 'x', species_ncbi_tax_id => '1',
   history => [{build_number => 'not-a-number', annotation_version => 'bogus'}]},
]});
is(join('|', map { $messy->{$_}{latest_annotation_version} // 'undef' } qw(messyBuilds onlyBad)),
   'newest|undef',
   'a non-numeric build_number is skipped: it neither wins nor disturbs the good rows');
