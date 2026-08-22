package ApiCommonModel::Model::ApolloRelease::Cli;

use strict;
use warnings;

use Getopt::Long qw(GetOptionsFromArray);

use ApiCommonModel::Model::ApolloRelease::Rename;
use ApiCommonModel::Model::ApolloRelease::Report;

# Everything in createApolloReleasePackage that can be decided without a
# database, a subprocess or a filesystem lives here rather than in the script.
#
# A Perl script cannot be `use`d by a test without running its main(), so logic
# left in Model/bin/ is logic that is never exercised until a release engineer
# runs it against prod.  That is precisely how the tool this replaces came to
# report success on an empty release: its argument handling, its thresholds and
# its rename detection had no seam anyone could test.  So the script is a thin
# wiring layer over this module, and every rule with a wrong answer worth
# catching is a class method here.
#
# In particular the RENAME RESOLUTION lives here and not in Rename.pm.  Rename.pm
# is finished and reviewed, and is about one thing: does this .fai describe the
# same assembly as that one.  Resolving a rename is a two-mechanism policy --
# consult apidb.organism first, fall back to assembly identity -- and the first
# mechanism needs no file I/O at all.  Putting it in Rename.pm would give that
# module a second, unrelated reason to change.

# ---------------------------------------------------------------------------
# Sanity floor for the portal organism count
# ---------------------------------------------------------------------------
#
# The portal returned 831 organisms on build 71, and an organism set only ever
# grows: an organism is retired by losing its reference/annotated flags, not by
# leaving the list.  So any large drop means the query, the model or the project
# name is wrong, not that VEuPathDB shrank.
#
# 500 is the floor, chosen against the one number that makes an undercount
# dangerous rather than merely odd: live prod Apollo holds 459 organisms, and
# every Apollo organism absent from the portal becomes a prune candidate.  Below
# ~459 the tool would be proposing to unpublish curated genomes on the strength
# of a broken query -- so the floor sits just above it.  It is far enough below
# 831 (a 40% loss) that ordinary curation churn, or a component database being
# reloaded, can never trip it.  A run that legitimately has fewer organisms than
# this does not exist today; when it does, this constant is the one place to
# argue about it.
use constant PORTAL_FLOOR => 500;

my $RENAME = 'ApiCommonModel::Model::ApolloRelease::Rename';
my $REPORT = 'ApiCommonModel::Model::ApolloRelease::Report';

my @ENVIRONMENTS = qw(qa prod);

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------

sub usage {
  return <<'USAGE';
createApolloReleasePackage --build N (--report | --generate) [options]

Builds the JBrowse configuration and sequence data that Apollo, the genome
curation platform, serves for a VEuPathDB release -- and the command files a
human then runs against Apollo.  It never calls a mutating Apollo endpoint.

Phases (exactly one, they cost differently):
  --report        minutes.  Portal + Apollo + overlay + rename resolution +
                  reconciliation, printed.  Changes nothing on disk.  This is
                  what goes to the curation team.
  --generate      hours.  Everything --report does, then builds the package for
                  the approved roster and writes the update command files.

Options:
  --build N               release build number                       (required)
  --environment qa|prod   which roster to write                    (default prod)
  --project NAME          WDK model name                          (default UniDB)
  --out-dir DIR           package root          (default $HOME/apolloConfigs)
  --base-url URL          absolutization base  (default https://veupathdb.org)
  --webservices-dir DIR   webServices tree holding the genomes
                          (default /var/www/Common/apiSiteFilesMirror/webServices)
  --previous-release DIR  the previous release's <env> directory, i.e. the one
                          containing data/.  Enables the assembly-identity
                          fallback for renames the database cannot explain.
  --organism ABBREV       narrow GENERATION to this organism; repeatable.
                          Reconciliation always runs over everything, so the
                          report and the safety invariants are unaffected.
  --apollo-roster FILE    read the Apollo roster from a saved
                          findAllOrganisms response instead of the API.  For
                          offline rehearsal; a real release uses the API.
  --force                 proceed past the pending-decision gate and past an
                          empty update bucket.  Neither is overridden lightly.
  --help                  this text

Output: <out-dir>/release-<build>/<environment>/
          data/<abbrev>/  twoBit/<abbrev>.2bit  updateCommands/  report.txt  report.tsv

Environment: GUS_HOME, and APOLLO_API_USER / APOLLO_API_PASS unless
--apollo-roster is given.  No password is ever read from the source.
USAGE
}

# Dies with a plain message (no Perl line noise) on any bad combination.  Reads
# nothing but @argv and %ENV{HOME}: --help and a missing required option must be
# answerable with no credentials, no GUS_HOME and no database.
sub parseOptions {
  my ($class, @argv) = @_;

  my %opt = (
    environment      => 'prod',
    project          => 'UniDB',
    out_dir          => ($ENV{HOME} || '.') . '/apolloConfigs',
    base_url         => 'https://veupathdb.org',
    ws_dir           => '/var/www/Common/apiSiteFilesMirror/webServices',
    organisms        => [],
  );

  my ($report, $generate, $help);

  my $parser = Getopt::Long::Parser->new(config => ['no_auto_abbrev', 'no_ignore_case']);

  # GetOptionsFromArray warns to stderr and returns false.  Turn that into the
  # same kind of death as every other bad option, so a caller sees one message.
  my $problem;
  local $SIG{__WARN__} = sub { $problem ||= $_[0] };

  $parser->getoptionsfromarray(
    \@argv,
    'report'             => \$report,
    'generate'           => \$generate,
    'help'               => \$help,
    'build=s'            => \$opt{build},
    'environment=s'      => \$opt{environment},
    'project=s'          => \$opt{project},
    'out-dir=s'          => \$opt{out_dir},
    'base-url=s'         => \$opt{base_url},
    'webservices-dir=s'  => \$opt{ws_dir},
    'previous-release=s' => \$opt{previous_release},
    'apollo-roster=s'    => \$opt{apollo_roster},
    'organism=s'         => $opt{organisms},
    'force'              => \$opt{force},
  ) or do { chomp(my $m = $problem || 'bad options'); die "$m\n" };

  die "unexpected argument(s): @argv\n" if @argv;

  # --help short-circuits every other rule.  It is the one invocation that must
  # work on a machine where nothing is configured.
  if ($help) {
    $opt{phase} = 'help';
    return \%opt;
  }

  die "exactly one of --report or --generate is required (they cost differently:\n"
    . "--report takes minutes and changes nothing; --generate takes hours)\n"
    unless ($report ? 1 : 0) + ($generate ? 1 : 0) == 1;

  $opt{phase} = $report ? 'report' : 'generate';

  die "--build N is required (the release build number)\n"
    unless defined $opt{build} && length $opt{build};
  die "--build must be a positive integer, got '$opt{build}'\n"
    unless $opt{build} =~ /^[1-9][0-9]*$/;
  $opt{build} += 0;

  die "--environment must be one of: @ENVIRONMENTS (got '$opt{environment}')\n"
    unless grep { $_ eq $opt{environment} } @ENVIRONMENTS;

  # --organism narrows generation only.  Accepting it on --report would produce
  # a report that looks filtered and is not, which is worse than refusing it.
  die "--organism narrows generation only and has no effect with --report;\n"
    . "the reconciliation always runs over every organism.\n"
    if @{$opt{organisms}} && $opt{phase} eq 'report';

  foreach my $key (qw(project base_url ws_dir out_dir)) {
    die "--" . ($key =~ s/_/-/gr) . " cannot be empty\n"
      unless defined $opt{$key} && length $opt{$key};
  }

  return \%opt;
}

sub outputDir {
  my ($class, $opt) = @_;
  return "$opt->{out_dir}/release-$opt->{build}/$opt->{environment}";
}

# ---------------------------------------------------------------------------
# Preflight -- everything checkable before any real work
# ---------------------------------------------------------------------------

# $env is passed in rather than read from %ENV so this is testable, and so the
# script has one place that decides which variables a run needs.  The Apollo
# credentials are genuinely not needed when the roster comes from a file.
sub assertEnvironment {
  my ($class, $env, $needApolloCredentials) = @_;

  my @required = ('GUS_HOME');
  push @required, qw(APOLLO_API_USER APOLLO_API_PASS) if $needApolloCredentials;

  foreach my $name (@required) {
    die "$name is not set.\n"
      . "Source the site's etc/setenv, and export the Apollo API credentials\n"
      . "(APOLLO_API_USER / APOLLO_API_PASS) -- they are never stored in the repo.\n"
      unless defined $env->{$name} && length $env->{$name};
  }

  return 1;
}

sub assertPreviousRelease {
  my ($class, $dir) = @_;

  return 1 unless defined $dir && length $dir;

  die "--previous-release $dir does not exist\n"        unless -e $dir;
  die "--previous-release $dir is not a directory\n"    unless -d $dir;
  die "--previous-release $dir is not readable\n"       unless -r $dir;

  return 1;
}

# The keys Generate::generateOrganism reads out of its %$opts.  A quality review
# flagged both failure modes this exists to stop: `wsdir` for `wsDir` fails deep
# into a run when the first genome cannot be found, and a missing `gusHome`
# never fails at all -- it degrades to running "/bin/<script>".
my @GENERATE_KEYS = qw(outDir base project build wsDir gusHome);

sub assertGenerateConfig {
  my ($class, $opts) = @_;

  my @missing = grep { !defined $opts->{$_} || !length $opts->{$_} } @GENERATE_KEYS;

  die "the generation config is missing or empty for: " . join(', ', @missing) . "\n"
    . "(required: " . join(', ', @GENERATE_KEYS) . ")\n"
    if @missing;

  return 1;
}

# ---------------------------------------------------------------------------
# Sanity checks -- refuse to proceed on absurd input
# ---------------------------------------------------------------------------

sub assertPortalSane {
  my ($class, $portal) = @_;

  my $count = scalar keys %$portal;

  die "the portal returned $count organism(s), which is implausibly low "
    . "(floor " . PORTAL_FLOOR . ", build 71 had 831).\n"
    . "Check --project, and check that jbrowseOrganismList is querying the\n"
    . "model you think it is.  Continuing would propose unpublishing curated\n"
    . "genomes on the strength of a broken query.\n"
    if $count < PORTAL_FLOOR;

  return 1;
}

# Apollo.pm dies on an empty roster from the API, with a message about
# credentials and Penn hosts.  loadFromFile has no such check -- an empty JSON
# array parses fine -- so the guard is applied here to BOTH sources, and names
# whichever one was used.
sub assertApolloSane {
  my ($class, $live, $source) = @_;

  die "Apollo returned no organisms from $source; the roster is empty.\n"
    . "The roster is the SEED for the release, so an empty one would make every\n"
    . "organism look new.  If this came from the API, check APOLLO_API_USER /\n"
    . "APOLLO_API_PASS and that you are on a Penn host -- it is IP-restricted.\n"
    unless %$live;

  return 1;
}

# Zero updates means every organism in Apollo vanished from the portal.  That is
# not a quiet zero: it is the shape a wrong --project or a half-loaded model
# takes, and the run that follows proposes 459 prunes.
sub assertUpdateBucketSane {
  my ($class, $result, $force) = @_;

  return 1 if @{$result->{update} || []};
  return 1 if $force;

  my $prunes = scalar @{$result->{prune_candidate} || []};

  die "the update bucket is empty: no organism in Apollo is on the portal.\n"
    . "That means every Apollo organism vanished from the portal ($prunes prune\n"
    . "candidate(s)), which is a broken input far more often than it is a real\n"
    . "release.  Re-run with --force if you genuinely mean it.\n";
}

# ---------------------------------------------------------------------------
# The --generate gate
# ---------------------------------------------------------------------------

# Commands::writeCommandFiles emits only APPROVED adds and prunes -- silently,
# and correctly: an unapproved candidate is a proposal.  But generating while
# decisions are pending therefore produces a package that is quietly missing
# them, and nothing in the output says so.  Refuse instead.
#
# GATE ON `total` ONLY.  pendingDecisions returns four numbers and only three of
# them count pending decisions: `annotated_prune` counts every prune holding
# annotations, approved or not, so it is NOT a subset of `prune` and can exceed
# `total`.  It answers "what is at stake if this runs", not "is a human still
# deciding" -- blocking on it would refuse a release the curation team has
# already approved, and reading it as a subset would under-report the risk.  It
# is surfaced by annotatedPruneWarning below, which is deliberately independent
# of this gate.
sub assertGenerationAllowed {
  my ($class, $result, $force) = @_;

  my $pending = $REPORT->pendingDecisions($result);

  return 1 unless $pending->{total};
  return 1 if $force;

  my @adds   = map { $_->{abbrev} } grep { !$_->{approved} } @{$result->{add_candidate}   || []};
  my @prunes = map { $_->{abbrev} } grep { !$_->{approved} } @{$result->{prune_candidate} || []};

  my $message = "refusing to --generate: $pending->{total} decision(s) are pending "
              . "($pending->{add} add, $pending->{prune} prune).\n";

  $message .= "  pending add(s):   " . join(', ', sort @adds) . "\n"    if @adds;
  $message .= "  pending prune(s): " . join(', ', sort @prunes) . "\n"  if @prunes;
  $message .= "  $pending->{annotated_prune} prune candidate(s) here hold human annotations "
            . "(approved or not).\n"
    if $pending->{annotated_prune};

  $message .= "Nothing is generated for an unapproved candidate, so the package would be\n"
            . "quietly missing them.  The fix is a roster-overlay entry -- an 'add' or\n"
            . "'remove' line with a reason in\n"
            . "  \$GUS_HOME/data/ApiCommonModel/Model/apollo/roster-overlay.txt\n"
            . "-- then re-run.  Run with --force only if you accept the omission.\n";

  die $message;
}

# The consequence, reported separately from the gate above and NOT suppressed
# by --force or by a clean decision count.  A run with zero pending decisions is
# precisely the run most likely to be executed without reading -- the curation
# team already approved everything -- and it can still be about to hide human
# annotations.  Returns undef when there is nothing at stake.
sub annotatedPruneWarning {
  my ($class, $result) = @_;

  my $pending = $REPORT->pendingDecisions($result);
  return undef unless $pending->{annotated_prune};

  my @annotated = sort map  { "$_->{abbrev} ($_->{annotation_count})" }
                       grep { ($_->{annotation_count} || 0) > 0 }
                       @{$result->{prune_candidate} || []};

  return "$pending->{annotated_prune} prune candidate(s) hold human annotations that "
       . "unpublishing will hide:\n  " . join(', ', @annotated) . "\n"
       . "Unpublishing is reversible -- Apollo keeps the data -- but nobody is told "
       . "when their work stops being visible.\n";
}

# ---------------------------------------------------------------------------
# The generation roster
# ---------------------------------------------------------------------------

# update + rename + APPROVED add_candidate, deduplicated and sorted, as portal
# organism records.  A rename is named by its NEW abbrev: that is the directory
# the package writes and the one Apollo will be repointed at.
sub generationRoster {
  my ($class, $result, $only) = @_;

  my %byAbbrev;

  $byAbbrev{$_->{abbrev}} = $_->{organism} for @{$result->{update} || []};
  $byAbbrev{$_->{to_abbrev}} = $_->{organism} for @{$result->{rename} || []};

  foreach my $add (@{$result->{add_candidate} || []}) {
    next unless $add->{approved};
    $byAbbrev{$add->{abbrev}} = $add->{organism};
  }

  return [map { $byAbbrev{$_} } sort keys %byAbbrev] unless $only && @$only;

  # An --organism naming something outside the roster would otherwise generate
  # a smaller package, or an empty one, and report success.  Say which.
  my @unknown = grep { !$byAbbrev{$_} } @$only;
  die "--organism named " . scalar(@unknown) . " abbrev(s) that are not in the\n"
    . "generation roster (update + rename + approved add): " . join(', ', @unknown) . "\n"
    . "A rename is named by its NEW abbrev.  An unapproved add candidate is not\n"
    . "in the roster and cannot be generated by naming it here.\n"
    if @unknown;

  my %want = map { $_ => 1 } @$only;
  return [map { $byAbbrev{$_} } grep { $want{$_} } sort keys %byAbbrev];
}

# When --organism narrows generation, the command files must describe the
# package that was actually built.  Emitting the full roster's commands
# alongside a partial package is how an Apollo organism gets repointed at a
# directory nobody generated.
sub narrowResult {
  my ($class, $result, $only) = @_;

  return $result unless $only && @$only;

  my %want = map { $_ => 1 } @$only;

  my %narrowed = %$result;
  $narrowed{update}          = [grep { $want{$_->{abbrev}} }    @{$result->{update}          || []}];
  $narrowed{rename}          = [grep { $want{$_->{to_abbrev}} } @{$result->{rename}          || []}];
  $narrowed{add_candidate}   = [grep { $want{$_->{abbrev}} }    @{$result->{add_candidate}   || []}];
  $narrowed{prune_candidate} = [grep { $want{$_->{abbrev}} }    @{$result->{prune_candidate} || []}];

  return \%narrowed;
}

# ---------------------------------------------------------------------------
# Rename resolution: the database first, assembly identity as a fallback
# ---------------------------------------------------------------------------

# $opts:
#   previous_release  - the previous release's <env> dir (enables the fallback)
#   ws_dir, project, build - locate this build's .fai files
#   previousFai, currentFai - coderef overrides for the two seams (tests)
#   rename_class      - override for Rename.pm (tests)
#
# Returns {renames => {from => to}, mechanism => {from => 'database'|'assembly'},
#          unresolved => [...], warnings => [...]}.
sub resolveRenames {
  my ($class, $portal, $live, $opts) = @_;

  $opts ||= {};

  my %renames;
  my %mechanism;
  my @warnings;

  # Case-sensitive throughout.  scerS288C and scerS288c are different
  # organisms, and two case-insensitive collisions exist in the namespace, so a
  # lc() anywhere in this path silently merges two genomes.  Perl hash lookup
  # and `eq` are exact; nothing here folds case, and nothing here should.
  my @orphans = grep { !exists $portal->{$_} } sort keys %$live;

  return {renames => {}, mechanism => {}, unresolved => [], warnings => []}
    unless @orphans;

  # --- 1. the database, which is authoritative ------------------------------
  #
  # apidb.organism carries abbrev (internal, stable) and public_abbrev.  A
  # reclassification changes the public one and leaves the internal one alone,
  # and Apollo's `directory` holds the public abbrev as of the release that
  # wrote it.  So an orphan naming an internal abbrev whose organism now
  # publishes under a different name IS that organism.  Measured on build 71:
  # 457 of 459 Apollo directories match a public abbrev, 2 match an internal
  # abbrev whose public differs, 0 match neither.
  #
  # NO FILTER on self-referential entries (internal eq public), deliberately.
  # One used to sit here, and it could not affect any outcome: for it to change
  # a lookup, an orphan's abbrev would have to equal an organism's internal
  # abbrev where that organism's PUBLIC abbrev is the same string -- and then
  # the orphan matches a public abbrev, so it is not an orphan and this hash is
  # never consulted for it.  Its only residual effect was to suppress the
  # duplicate warning below in a state where one organism's public abbrev
  # equals another's internal abbrev, which is a genuine data anomaly that
  # deserves to be said out loud rather than filtered away.  A guard nothing
  # can reach is how the script this replaces accumulated its dead branches, so
  # it is gone rather than pinned by a test that could only assert an
  # equivalence.  The ~794 identity entries it used to exclude are inert.
  my %publicByInternal;
  foreach my $organism (values %$portal) {
    my $internal = $organism->{internal_abbrev};
    next unless defined $internal && length $internal;

    # No internal abbrev repeats today (measured over all 831).  If one ever
    # does, both readings are equally defensible, so take neither.
    if (exists $publicByInternal{$internal}) {
      push @warnings,
        "internal abbrev '$internal' belongs to more than one portal organism "
        . "($publicByInternal{$internal} and $organism->{abbrev}); refusing to use "
        . "it to resolve a rename.";
      $publicByInternal{$internal} = undef;
      next;
    }

    $publicByInternal{$internal} = $organism->{abbrev};
  }

  my %renameTarget;
  my @unresolved;

  foreach my $orphan (@orphans) {
    my $to = $publicByInternal{$orphan};

    unless (defined $to) {
      push @unresolved, $orphan;
      next;
    }

    # Repointing onto an abbrev Apollo already holds is a merge, not a rename:
    # two Apollo organisms would share one directory, and Reconcile refuses the
    # whole run over it.  Decline the rename instead -- the orphan stays a
    # prune candidate a human judges, which is the recoverable outcome.
    if ($live->{$to}) {
      push @warnings,
        "$orphan: the database says it is now '$to', but '$to' is already in Apollo. "
        . "That is a merge, not a rename; declining. Treating as a prune candidate.";
      next;
    }

    $renames{$orphan}     = $to;
    $mechanism{$orphan}   = 'database';
    $renameTarget{$to}    = $orphan;
  }

  # --- 2. assembly identity, for what the database cannot explain -----------
  return {renames => \%renames, mechanism => \%mechanism,
          unresolved => [], warnings => \@warnings}
    unless @unresolved;

  unless ($opts->{previous_release}) {
    push @warnings,
      "$_: the database cannot explain this orphan and no --previous-release was "
      . "given, so the assembly-identity fallback did not run. This is NOT evidence "
      . "the genome changed. Treating as a prune candidate."
      for @unresolved;

    return {renames => \%renames, mechanism => \%mechanism,
            unresolved => \@unresolved, warnings => \@warnings};
  }

  my $renameClass = $opts->{rename_class} || $RENAME;

  my $previousFai = $opts->{previousFai} || sub {
    my ($abbrev) = @_;
    return "$opts->{previous_release}/data/$abbrev/seq/$abbrev.fa.fai";
  };

  my $currentFai = $opts->{currentFai} || sub {
    my ($organism) = @_;
    return undef unless $organism->{name_for_filenames};
    return "$opts->{ws_dir}/$opts->{project}/build-$opts->{build}"
         . "/$organism->{name_for_filenames}/genomeAndProteome/fasta/genome.fasta.fai";
  };

  # No strain filter is passed.  An orphan is BY DEFINITION absent from the
  # portal, so the only strain evidence available is Apollo's commonName -- and
  # commonName is editable in the Apollo GUI, which is exactly why Apollo.pm
  # refuses to match on it anywhere else.  Rename.pm handles an undef strain by
  # comparing against every portal organism and saying so; that costs one pass
  # over ~831 index files, on the rare orphan the database could not explain,
  # and the sequence comparison is what decides either way.
  my $detected = $renameClass->detect(\@unresolved, $portal,
                                      $previousFai, $currentFai, {});

  push @warnings, $renameClass->warnings();

  my %stillUnresolved = map { $_ => 1 } @unresolved;

  foreach my $from (sort keys %$detected) {
    my $to = $detected->{$from};

    if ($live->{$to}) {
      push @warnings,
        "$from: its assembly matches '$to', but '$to' is already in Apollo. "
        . "That is a merge, not a rename; declining. Treating as a prune candidate.";
      next;
    }

    # Two orphans whose assemblies both match one portal organism.  Reconcile
    # dies on that ("two organisms renamed to X"); catch it here, where the
    # cause can be named and the release can still report.
    if (exists $renameTarget{$to}) {
      push @warnings,
        "$from: its assembly matches '$to', but '$to' is already the rename target of "
        . "'$renameTarget{$to}'. Two organisms cannot be renamed onto one directory; "
        . "declining. Treating as a prune candidate.";
      next;
    }

    $renames{$from}   = $to;
    $mechanism{$from} = 'assembly';
    $renameTarget{$to} = $from;
    delete $stillUnresolved{$from};
  }

  return {renames    => \%renames,
          mechanism  => \%mechanism,
          unresolved => [sort keys %stillUnresolved],
          warnings   => \@warnings};
}

1;
