use strict;
use warnings;
use Test::More tests => 9;
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
