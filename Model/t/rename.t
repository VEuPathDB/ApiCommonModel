use strict;
use warnings;
use Test::More tests => 17;
use File::Temp qw(tempdir);
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Rename;

my $R = 'ApiCommonModel::Model::ApolloRelease::Rename';

my $dir = tempdir(CLEANUP => 1);

sub writeFai {
  my ($path, @lines) = @_;
  open(my $fh, '>', $path) or die $!;
  print $fh "$_\n" for @lines;
  close $fh;
}

# Old organism's shipped index, and a new organism with the same assembly.
writeFai("$dir/old.fai",   "AE017341.1\t2300533\t60\t60\t61", "AE017342.1\t1632307\t60\t60\t61");
writeFai("$dir/same.fai",  "AE017341.1\t2300533\t99\t70\t71", "AE017342.1\t1632307\t99\t70\t71");
writeFai("$dir/other.fai", "CP000001.1\t123456\t60\t60\t61");

is_deeply($R->readFai("$dir/old.fai"),
          {'AE017341.1' => 2300533, 'AE017342.1' => 1632307},
          'fai parsed to name => length, ignoring offset columns');

ok($R->sameAssembly("$dir/old.fai", "$dir/same.fai"),
   'identical names and lengths match despite different byte offsets');
ok(!$R->sameAssembly("$dir/old.fai", "$dir/other.fai"),
   'different assembly does not match');

my $portal = {
  cdenJEC21 => {abbrev => 'cdenJEC21', strain_abbrev => 'JEC21', name_for_filenames => 'CdeneoformansJEC21'},
  tgonME49  => {abbrev => 'tgonME49',  strain_abbrev => 'ME49',  name_for_filenames => 'TgondiiME49'},
};

my $renames = $R->detect(
  ['cneoJEC21'],
  $portal,
  sub { my ($abbrev) = @_; return "$dir/old.fai" },
  sub { my ($org) = @_; return $org->{abbrev} eq 'cdenJEC21' ? "$dir/same.fai" : "$dir/other.fai" },
  {cneoJEC21 => 'JEC21'},
);

is_deeply($renames, {cneoJEC21 => 'cdenJEC21'}, 'rename detected by sequence identity');

# A missing previous-release index must not silently mean "no rename".
my $none = $R->detect(['cneoJEC21'], $portal,
                      sub { return "$dir/does-not-exist.fai" },
                      sub { return "$dir/same.fai" },
                      {cneoJEC21 => 'JEC21'});
is_deeply($none, {}, 'unresolvable organism yields no rename');

my @warnings = $R->warnings();
like($warnings[0], qr/cneoJEC21/, 'and says so rather than staying silent');

# --- degenerate index files -------------------------------------------------
# Each of these is a file that EXISTS, so the caller's -e check passes and the
# only thing standing between it and a wrong answer is readFai.

writeFai("$dir/empty.fai");
is_deeply($R->readFai("$dir/empty.fai"), {}, 'an empty index parses to an empty hash');
ok(!$R->sameAssembly("$dir/empty.fai", "$dir/empty.fai"),
   'two empty indexes are NOT the same assembly -- no assembly has zero sequences');

# samtools killed mid-write: a final line with a name but no length.
writeFai("$dir/truncated.fai", "AE017341.1\t2300533\t60\t60\t61", "AE017342.1");
is($R->readFai("$dir/truncated.fai"), undef, 'a truncated index is refused, not partly believed');
ok(!$R->sameAssembly("$dir/old.fai", "$dir/truncated.fai"),
   'and so cannot match on the intact prefix of a different assembly');
ok((grep { /truncated\.fai/ } $R->warnings()), 'a refused index is reported');

# --- the ambiguous case -----------------------------------------------------
# Two portal organisms sharing a strain abbrev AND an assembly.  This is the
# case where a guess would repoint curated annotations onto the wrong genome.

my $ambiguous = {
  cdenJEC21 => {abbrev => 'cdenJEC21', strain_abbrev => 'JEC21'},
  cdupJEC21 => {abbrev => 'cdupJEC21', strain_abbrev => 'JEC21'},
};
my $tie = $R->detect(['cneoJEC21'], $ambiguous,
                     sub { return "$dir/old.fai" },
                     sub { return "$dir/same.fai" },
                     {cneoJEC21 => 'JEC21'});
is_deeply($tie, {}, 'two equally good matches produce NO rename rather than a guess');
ok((grep { /cdenJEC21.*cdupJEC21|refusing to guess/ } $R->warnings()),
   'and the ambiguity is named, not swallowed');

# --- an orphan whose strain abbrev could not be parsed -----------------------
# The strain filter bounds how many files get opened; sequence identity is what
# decides.  So an unparseable strain must widen the search, not abandon it --
# otherwise an Apollo commonName the parser does not understand silently costs
# a rename and orphans its annotations.

my $noStrain = $R->detect(['cneoJEC21'], $portal,
                          sub { return "$dir/old.fai" },
                          sub { my ($o) = @_; return $o->{abbrev} eq 'cdenJEC21' ? "$dir/same.fai" : "$dir/other.fai" },
                          {});
is_deeply($noStrain, {cneoJEC21 => 'cdenJEC21'},
          'an unknown strain falls back to every portal organism and still finds the rename');
ok((grep { /no strain abbrev/ } $R->warnings()),
   'the widened search is reported, since it is the slow path');

# A strain that matches nothing on the portal must not quietly become a
# full scan -- it is a real filter, and an empty candidate set is an answer.
my $wrongStrain = $R->detect(['cneoJEC21'], $portal,
                             sub { return "$dir/old.fai" },
                             sub { return "$dir/same.fai" },
                             {cneoJEC21 => 'NOSUCHSTRAIN'});
is_deeply($wrongStrain, {}, 'a strain matching no portal organism yields no rename');

# The current index may legitimately not exist yet for some portal organism;
# that must skip the candidate, not abort the whole orphan.
my $missingCurrent = $R->detect(['cneoJEC21'], $portal,
                                sub { return "$dir/old.fai" },
                                sub { my ($o) = @_; return $o->{abbrev} eq 'cdenJEC21' ? "$dir/same.fai" : "$dir/gone.fai" },
                                {});
is_deeply($missingCurrent, {cneoJEC21 => 'cdenJEC21'},
          'a candidate with no current index is skipped, not fatal');
