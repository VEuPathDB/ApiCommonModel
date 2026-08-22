use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Commands;

my $C = 'ApiCommonModel::Model::ApolloRelease::Commands';

sub slurp {
  my ($path) = @_;
  open(my $fh, '<', $path) or die "Cannot read $path: $!";
  local $/;
  my $content = <$fh>;
  close $fh;
  return $content;
}

# ---------------------------------------------------------------- update

my $update = $C->updateCommand({
  abbrev => 'tgonME49', apollo_id => 1484940, public_mode => 1,
});

like($update, qr/"id":"1484940"/,                          'update targets the numeric apollo id');
like($update, qr{"directory":"/data/apollo_data/tgonME49"},
     'update points at the organism directory');
like($update, qr{"blatdb":"/data/apollo_data/twoBit/tgonME49\.2bit"},
     'update points at the twoBit blatdb');
like($update, qr{\Qhttps://apollo-api.veupathdb.org/organism/updateOrganismInfo\E},
     'update posts to updateOrganismInfo');
like($update, qr/"publicMode":"true"/, 'a public organism stays public through an update');

# --------------------------------------------------- visibility is echoed

# 17 live organisms are curator-hidden, 3 of them carrying annotations.  The
# previous script hardcoded "publicMode":"true", which re-published all 17.
my $hidden = $C->updateCommand({abbrev => 'treeQM6a', apollo_id => 9999, public_mode => 0});
like($hidden,   qr/"publicMode":"false"/,
     'a hidden organism stays hidden through an update');
unlike($hidden, qr/"publicMode":"true"/,
     'and the hidden update contains no publicMode:true anywhere');

eval { $C->updateCommand({abbrev => 'x', apollo_id => 1}) };
like($@, qr/refusing to guess visibility/,
     'a missing public_mode is a hard error, not a default');

eval { $C->renameCommand({from_abbrev => 'a', to_abbrev => 'b', apollo_id => 1,
                          organism => {name => 'A b'}}) };
like($@, qr/refusing to guess visibility/,
     'a rename with no public_mode is a hard error too');

# ---------------------------------------------------------------- rename

# cneoJEC21 (id 2452162) holds 14 human-made annotations and is now cdenJEC21.
# Repointing the EXISTING id preserves them; add-new + prune-old orphans them.
my $rename = $C->renameCommand({
  from_abbrev => 'cneoJEC21', to_abbrev => 'cdenJEC21',
  apollo_id => 2452162, public_mode => 1, annotation_count => 14,
  organism => {name => 'Cryptococcus deneoformans JEC21',
               latest_annotation_version => 'Jun 16, 2016'},
});

like($rename,   qr/"id":"2452162"/,
     'a rename targets the EXISTING apollo id, so annotations survive');
unlike($rename, qr/cneoJEC21/,
     'and the OLD abbrev appears nowhere in the paths');
like($rename,   qr{"directory":"/data/apollo_data/cdenJEC21"},
     'a rename repoints directory at the new abbrev');
like($rename,   qr{"blatdb":"/data/apollo_data/twoBit/cdenJEC21\.2bit"},
     'a rename repoints blatdb at the new abbrev');
like($rename,   qr/"commonName":"Cryptococcus deneoformans JEC21 \[Jun 16, 2016\]"/,
     'a rename sets commonName to "<name> [<annotation version>]"');
like($rename,   qr/"publicMode":"true"/, 'a rename echoes back the current visibility');

my $hiddenRename = $C->renameCommand({
  from_abbrev => 'a', to_abbrev => 'b', apollo_id => 7, public_mode => 0,
  organism => {name => 'Some organism', latest_annotation_version => '2020-01-01'},
});
like($hiddenRename, qr/"publicMode":"false"/, 'a hidden organism stays hidden through a rename');

# ----------------------------------------------------------------- prune

my $prune = $C->pruneCommand({abbrev => 'cglaCBS138', apollo_id => 5146948});
like($prune,   qr/"publicMode":"false"/, 'a prune unpublishes');
unlike($prune, qr/"publicMode":"true"/,  'a prune never publishes');
unlike($prune, qr/\b(delete|remove|deleteOrganism)\b/i,
       'a prune carries no delete verb -- unpublishing is reversible');
like($prune,   qr{/organism/updateOrganismInfo},
     'a prune goes through updateOrganismInfo like everything else');

# ------------------------------------------------------------------- add

my $add = $C->addCommand({
  abbrev   => 'pberANKA',
  approved => 1,
  organism => {name => 'Plasmodium berghei ANKA',
               latest_annotation_version => 'Mar 2021'},
});

like($add, qr/^groovy add_organism\.groovy /m, 'an add emits add_organism.groovy');
like($add, qr/^groovy alter_group_permissions\.groovy /m,
     'and alter_group_permissions.groovy alongside it');
like($add, qr/-name 'Plasmodium berghei ANKA \[Mar 2021\]'/,
     'the new organism is named "<name> [<annotation version>]"');
like($add, qr{-directory '/data/apollo_data/pberANKA'}, 'the add names the organism directory');
like($add, qr{-blatdb '/data/apollo_data/twoBit/pberANKA\.2bit'}, 'and its blatdb');

# ------------------------------------------- an organism with no annotation version

# _latestAnnotationVersion returns undef when an organism has no usable history
# row.  Apollo's name is then the bare portal name: an empty "[]" would become
# part of the organism's identity in Apollo and would never match again.
my $noVersion = $C->addCommand({
  abbrev => 'xxxNOVER', approved => 1, organism => {name => 'Genus species NOVER'},
});
like($noVersion,   qr/-name 'Genus species NOVER'/,
     'no annotation version -> the bare portal name');
unlike($noVersion, qr/\[|\]/,
       'and no empty brackets, which would be baked into the Apollo identity');

my $noVersionRename = $C->renameCommand({
  from_abbrev => 'old', to_abbrev => 'new', apollo_id => 42, public_mode => 1,
  organism => {name => 'Genus species NOVER'},
});
like($noVersionRename,   qr/"commonName":"Genus species NOVER"/,
     'a rename with no annotation version uses the bare name');
unlike($noVersionRename, qr/\[|\]/, 'and emits no empty brackets either');

# ------------------------------------------------------------- no passwords

# These files land in a shared directory and get pasted into tickets.  Every
# password-bearing field must hold the literal shell variable, unexpanded.
sub passwordValues {
  my ($text) = @_;
  my @values;
  while ($text =~ /(?:"password"\s*:\s*"([^"]*)"|-adminpassword\s+(\S+)|-password\s+(\S+))/g) {
    push @values, defined $1 ? $1 : defined $2 ? $2 : $3;
  }
  return @values;
}

for my $pair (['update', $update], ['rename', $rename], ['prune', $prune], ['add', $add]) {
  my ($what, $text) = @$pair;
  my @values = passwordValues($text);
  ok(scalar @values, "$what carries at least one password field");
  is_deeply([grep { $_ ne '$APOLLO_ADMIN_PASSWORD' } @values], [],
            "$what interpolates no literal password -- only \$APOLLO_ADMIN_PASSWORD");
}

like($update, qr/"username":"admin\@local\.host"/, 'the admin user is admin@local.host');

# --------------------------------------------- punctuation in an organism name

# Strain and isolate names carry punctuation, and the portal is the source of
# that string.  An apostrophe reaching the emitted line would terminate the
# shell's quoting of --data and turn the rest of the JSON into shell words; a
# double quote or a backslash would break the JSON instead.  Both must refuse
# to emit rather than produce a line whose meaning depends on the shell.
#
# Asserted as facts, not prose: it dies, the message shows the offending value
# so a reader can see WHICH organism, and it shows the offending character.
sub dieFor {
  my ($code) = @_;
  eval { $code->(); 1 };
  return $@;
}

sub renameNamed {
  my ($name) = @_;
  return sub {
    $C->renameCommand({
      from_abbrev => 'lspGHANA_old', to_abbrev => 'lspGHANA', apollo_id => 3311,
      public_mode => 1, organism => {name => $name, latest_annotation_version => 'Jan 2024'},
    });
  };
}

my $quotedName = q{Leishmania sp. 'ghana'};
my $squote = dieFor(renameNamed($quotedName));
ok($squote, 'a single quote in a rename commonName refuses to emit');
like($squote, qr/\Q$quotedName\E/, 'and the error shows the offending organism name');
like($squote, qr/'/,               'and the offending character itself');

my $dquoteName = q{Leishmania sp. "ghana"};
my $dquote = dieFor(renameNamed($dquoteName));
ok($dquote, 'a double quote in a rename commonName refuses to emit');
like($dquote, qr/\Q$dquoteName\E/, 'and the error shows the offending organism name');
like($dquote, qr/"/,               'and the offending character itself');

my $slashName = q{Leishmania sp. \ghana};
my $slash = dieFor(renameNamed($slashName));
ok($slash, 'a backslash in a rename commonName refuses to emit');
like($slash, qr/\Q$slashName\E/, 'and the error shows the offending organism name');
like($slash, qr/\\/,             'and the offending character itself');

# The shell-quoting failure and the JSON failure are different problems with
# different fixes, so a reader must be able to tell which one they hit.
isnt($squote, $dquote, 'the single-quote and double-quote diagnoses differ');

# The same hazard reaches addCommand by its own path -- the name is
# shell-quoted there rather than embedded in JSON, so it has its own guard.
my $addQuoted = dieFor(sub {
  $C->addCommand({abbrev => 'lspGHANA', approved => 1,
                  organism => {name => $quotedName, latest_annotation_version => 'Jan 2024'}});
});
ok($addQuoted, 'a single quote in an added organism name refuses to emit');
like($addQuoted, qr/\Q$quotedName\E/, 'and the add error shows the offending organism name');
like($addQuoted, qr/'/,               'and the offending character itself');

# A clean name with other punctuation must still go through: the guard is about
# three specific characters, not a general distrust of the portal.
my $punctuated = $C->addCommand({
  abbrev => 'psp_G1', approved => 1,
  organism => {name => 'Plasmodium sp. gorilla clade G1 (strain-2)',
               latest_annotation_version => 'Jan 2024'},
});
like($punctuated, qr/-name 'Plasmodium sp\. gorilla clade G1 \(strain-2\)/,
     'ordinary punctuation in a name is not rejected');

# ---------------------------------------------------- writing the two files

my $organism = sub {
  my ($name, $version) = @_;
  return {name => $name, latest_annotation_version => $version};
};

my $result = {
  update => [
    {abbrev => 'tgonME49', apollo_id => 1484940, public_mode => 1,
     organism => $organism->('Toxoplasma gondii ME49', '2021-05-01')},
    {abbrev => 'treeQM6a', apollo_id => 9999, public_mode => 0,
     organism => $organism->('Trichoderma reesei QM6a', '2019-01-01')},
  ],
  rename => [
    {from_abbrev => 'cneoJEC21', to_abbrev => 'cdenJEC21', apollo_id => 2452162,
     public_mode => 1, annotation_count => 14,
     organism => $organism->('Cryptococcus deneoformans JEC21', 'Jun 16, 2016')},
  ],
  prune_candidate => [
    {abbrev => 'cglaCBS138', apollo_id => 5146948, annotation_count => 0,
     approved => 1, reason => 'no longer a reference strain'},
    {abbrev => 'unapprovedP', apollo_id => 111, annotation_count => 0, approved => 0},
  ],
  add_candidate => [
    {abbrev => 'pberANKA', approved => 1, reason => 'new reference',
     organism => $organism->('Plasmodium berghei ANKA', 'Mar 2021')},
    {abbrev => 'unapprovedA', approved => 0,
     organism => $organism->('Genus unapproved', 'Jan 2020')},
  ],
};

my $dir = tempdir(CLEANUP => 1);
$C->writeCommandFiles($result, $dir, build => '68', date => '2026-08-21');

my $curl   = slurp("$dir/Apollo_curl");
my $groovy = slurp("$dir/Apollo_groovy");

unlike($curl,   qr/unapprovedP/, 'an UNAPPROVED prune produces no command');
like($curl,     qr/"id":"5146948"/, 'an approved prune does');
unlike($groovy, qr/unapprovedA/, 'an UNAPPROVED add produces no command');
like($groovy,   qr/pberANKA/,    'an approved add does');

my @commands = grep { !/^\s*#/ && /\S/ } split(/\n/, $curl);
is(scalar @commands, 4,
   'Apollo_curl holds exactly updates + renames + APPROVED prunes');

# A partial run should leave everything published: the renames (the entries
# carrying annotations) go first, the unpublishes last.
like($commands[0], qr/2452162/,  'renames are emitted first');
like($commands[3], qr/5146948/,  'prunes are emitted last');

like($curl,   qr/^#/m, 'Apollo_curl carries a header comment');
like($curl,   qr/2026-08-21/, 'the header records the date it was generated');
like($curl,   qr/\b68\b/,     'and the build it belongs to');
like($groovy, qr/^#/m,        'Apollo_groovy carries a header comment too');

# An approved prune of an annotated organism is still emitted -- approval is the
# human gate and unpublishing is reversible -- but never silently.
my $annotated = {
  update => [], rename => [], add_candidate => [],
  prune_candidate => [
    {abbrev => 'cneoOLD', apollo_id => 777, annotation_count => 14, approved => 1,
     reason => 'superseded'},
  ],
};
my $dir2 = tempdir(CLEANUP => 1);
$C->writeCommandFiles($annotated, $dir2);
my $curl2 = slurp("$dir2/Apollo_curl");
like($curl2, qr/"id":"777"/, 'an approved prune of an annotated organism is emitted');
like($curl2, qr/#[^\n]*14[^\n]*annotation/i,
     'but is preceded by a comment naming its annotation count');

for my $text ($curl, $groovy, $curl2) {
  unlike($text, qr/APOLLO_ADMIN_PASSWORD=/, 'no generated file assigns a password value');
}

done_testing();
