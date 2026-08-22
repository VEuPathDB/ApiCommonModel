use strict;
use warnings;
use Test::More tests => 15;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Apollo;

my $A = 'ApiCommonModel::Model::ApolloRelease::Apollo';

my $live = $A->loadFromFile("Model/t/fixtures/apollo.json");

is(ref($live), 'HASH', 'returns a hash keyed by abbrev');
is(scalar(keys %$live), 5, 'all five organisms parsed');

my $t = $live->{tgonME49};
is($t->{id}, 1484940, 'numeric id carried');
is($t->{annotation_count}, 10, 'annotation count carried');
is($t->{abbrev}, 'tgonME49', 'abbrev parsed from directory');

my $c = $live->{cneoJEC21};
is($c->{annotation_count}, 14, 'the organism we must not lose is parsed');

# commonName is curator-editable, so it is cross-checked, never matched on.
is($A->commonNameDisagrees($live->{pfal3D7}, 'Plasmodium falciparum 3D7'), 1,
   'GUI-edited common name is flagged');
is($A->commonNameDisagrees($live->{tgonME49}, 'Toxoplasma gondii ME49'), 0,
   'matching common name is not flagged');

# Not every Apollo organism carries an annotation-version bracket.  The strip
# is anchored, so a bracket-free name must compare whole rather than being
# treated as a mismatch (which would raise a cross-check warning on every
# such organism, every release).
is($A->commonNameDisagrees({common_name => 'Plasmodium falciparum 3D7'},
                           'Plasmodium falciparum 3D7'), 0,
   'bracket-free common name still matches');

# publicMode arrives as a JSON boolean object, which is an object reference in
# Perl.  Pin the coercion so downstream comparisons see plain 0/1.
is($live->{tgonME49}{public_mode}, 1, 'publicMode true becomes 1');
is($live->{cglaCBS138}{public_mode}, 0, 'publicMode false becomes 0');

# annotationCount is the value that decides whether an organism can be safely
# removed.  A missing key must read as 0, not undef -- undef would warn under
# numeric comparison and could compare as "no annotations" by accident anyway.
my $noCount = $A->normalise([
  {id => 1, commonName => 'X', directory => '/data/apollo_data/xxxx'},
]);
is($noCount->{xxxx}{annotation_count}, 0, 'absent annotationCount defaults to 0');

# A trailing slash on directory is the same organism, not a different one.
my $slashed = $A->normalise([
  {id => 2, commonName => 'Y', directory => '/data/apollo_data/tgonME49/'},
]);
is_deeply([keys %$slashed], ['tgonME49'], 'trailing slash on directory is stripped');

# Two Apollo organisms sharing a directory is corruption: silently keeping the
# last one would hide an organism from the diff and could generate a delete
# against the wrong record.  Fail loudly instead.
eval {
  $A->normalise([
    {id => 10, commonName => 'A', directory => '/data/apollo_data/dupe', annotationCount => 0},
    {id => 11, commonName => 'B', directory => '/data/apollo_data/dupe', annotationCount => 7},
  ]);
};
like($@, qr/two organisms with directory .*dupe.*\n?.*ids 10 and 11/s,
     'duplicate directory is a fatal error naming both ids');

# A directory that yields no final path segment must be skipped, not keyed
# under the empty string -- which would collide across every such record and
# put a nameless entry into the roster the release commands iterate.
my @warnings;
my $bad = do {
  local $SIG{__WARN__} = sub { push @warnings, $_[0] };
  $A->normalise([{id => 99, commonName => 'Z', directory => ''}]);
};
is_deeply($bad, {}, 'organism with an unparseable directory is skipped, not keyed as ""');
