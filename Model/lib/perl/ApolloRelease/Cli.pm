package ApiCommonModel::Model::ApolloRelease::Cli;

use strict;
use warnings;

use Getopt::Long qw(GetOptionsFromArray);

use ApiCommonModel::Model::ApolloRelease::Rename;
use ApiCommonModel::Model::ApolloRelease::Report;

# Everything in createApolloReleasePackage decidable without a database, a
# subprocess or a filesystem.  A Perl script cannot be `use`d by a test without
# running its main(), so logic left in Model/bin/ is never exercised until a
# release engineer runs it against prod -- which is how the tool this replaces
# came to report success on an empty release.  The script is thin wiring; every
# rule with a wrong answer worth catching is a class method here.
#
# RENAME RESOLUTION lives here, not in Rename.pm, which answers one question:
# does this .fai describe the same assembly as that one.  Resolving a rename is
# a two-mechanism policy whose first mechanism needs no file I/O, and putting it
# there would give that module a second reason to change.

# Sanity floor for the portal organism count.
#
# An organism set only ever grows -- retirement is losing the reference/annotated
# flags, not leaving the list -- so a large drop means the query, the model or
# the project name is wrong.
#
# The floor sits just above the size of the live Apollo roster, because every
# Apollo organism absent from the portal becomes a prune candidate: below that
# the tool would propose unpublishing curated genomes on the strength of a broken
# query.  It is far enough below the real portal count that curation churn or a
# component database reload cannot trip it.
use constant PORTAL_FLOOR => 500;

my $RENAME = 'ApiCommonModel::Model::ApolloRelease::Rename';
my $REPORT = 'ApiCommonModel::Model::ApolloRelease::Report';

my @ENVIRONMENTS = qw(qa prod);

# --- Options ---

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
  --roster-overlay FILE   read the roster overlay from FILE instead of the
                          copy installed under GUS_HOME.  For a release's
                          own approvals, which need no long-term home.
  --apollo-roster FILE    read the Apollo roster from a saved
                          findAllOrganisms response instead of the API.  For
                          offline rehearsal; a real release uses the API.
  --force                 proceed past the pending-decision gate and past an
                          empty update bucket.  Neither is overridden lightly.
  --help                  this text

Output: <out-dir>/release-<build>/<environment>/
          data/<abbrev>/  data/twoBit/<abbrev>.2bit  updateCommands/  report.txt  report.tsv

Environment: GUS_HOME, and APOLLO_API_USER / APOLLO_API_PASS unless
--apollo-roster is given.  No password is ever read from the source.
USAGE
}

# Dies with a plain message on any bad combination.  Reads nothing but @argv and
# $ENV{HOME}: --help and a missing option must be answerable with no
# credentials, no GUS_HOME and no database.
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

  # GetOptionsFromArray warns to stderr and returns false; turn that into the
  # same death as every other bad option so a caller sees one message.
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
    'roster-overlay=s'   => \$opt{roster_overlay},
    'organism=s'         => $opt{organisms},
    'force'              => \$opt{force},
  ) or do { chomp(my $m = $problem || 'bad options'); die "$m\n" };

  die "unexpected argument(s): @argv\n" if @argv;

  # --help short-circuits every other rule: the one invocation that must work on
  # a machine where nothing is configured.
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

  # Accepting --organism on --report would produce a report that looks filtered
  # and is not, which is worse than refusing it.
  die "--organism narrows generation only and has no effect with --report;\n"
    . "the reconciliation always runs over every organism.\n"
    if @{$opt{organisms}} && $opt{phase} eq 'report';

  foreach my $key (qw(project base_url ws_dir out_dir)) {
    die "--" . ($key =~ s/_/-/gr) . " cannot be empty\n"
      unless defined $opt{$key} && length $opt{$key};
  }

  # Distinct from the loop above: this option has no default, so an empty value
  # would silently mean "use the installed copy" -- the opposite of the intent.
  die "--roster-overlay cannot be empty\n"
    if defined $opt{roster_overlay} && !length $opt{roster_overlay};

  return \%opt;
}

sub outputDir {
  my ($class, $opt) = @_;
  return "$opt->{out_dir}/release-$opt->{build}/$opt->{environment}";
}

# The installed copy carries STANDING policy -- host genomes, model fungi -- and
# overlay.t pins its shape, so a release's own approvals cannot live there.
# --roster-overlay replaces it wholesale; the report always names the path read.
sub overlayPath {
  my ($class, $opt, $env) = @_;

  my $override = $opt->{roster_overlay};
  return $override if defined $override && length $override;

  die "GUS_HOME is not set, so the installed roster overlay cannot be located.\n"
    . "Set it, or name a file with --roster-overlay.\n"
    unless defined $env->{GUS_HOME} && length $env->{GUS_HOME};

  return "$env->{GUS_HOME}/data/ApiCommonModel/Model/apollo/roster-overlay.txt";
}

# --- Preflight -- everything checkable before any real work ---

# $env is passed in rather than read from %ENV so this is testable, and so one
# place decides which variables a run needs.
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

# Checked before the roster and the portal are read: a typo here should cost a
# second, not the minutes those two take.
sub assertRosterOverlay {
  my ($class, $path) = @_;

  return 1 unless defined $path && length $path;

  die "--roster-overlay $path does not exist\n"    unless -e $path;
  die "--roster-overlay $path is not a file\n"     unless -f $path;
  die "--roster-overlay $path is not readable\n"   unless -r $path;

  return 1;
}

# The keys Generate::generateOrganism reads out of its %$opts.  Both failure
# modes are silent-ish: `wsdir` for `wsDir` fails deep into a run, and a missing
# `gusHome` never fails at all -- it degrades to running "/bin/<script>".
my @GENERATE_KEYS = qw(outDir base project build wsDir gusHome);

sub assertGenerateConfig {
  my ($class, $opts) = @_;

  my @missing = grep { !defined $opts->{$_} || !length $opts->{$_} } @GENERATE_KEYS;

  die "the generation config is missing or empty for: " . join(', ', @missing) . "\n"
    . "(required: " . join(', ', @GENERATE_KEYS) . ")\n"
    if @missing;

  return 1;
}

# --- Sanity checks -- refuse to proceed on absurd input ---

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

# Apollo.pm dies on an empty roster from the API, but loadFromFile has no such
# check -- an empty JSON array parses fine -- so guard both sources here and name
# whichever was used.
sub assertApolloSane {
  my ($class, $live, $source) = @_;

  die "Apollo returned no organisms from $source; the roster is empty.\n"
    . "The roster is the SEED for the release, so an empty one would make every\n"
    . "organism look new.  If this came from the API, check APOLLO_API_USER /\n"
    . "APOLLO_API_PASS and that you are on a Penn host -- it is IP-restricted.\n"
    unless %$live;

  return 1;
}

# Zero updates means every Apollo organism vanished from the portal.  That is
# the shape a wrong --project or a half-loaded model takes, and the run that
# follows proposes pruning the entire roster.
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

# --- The --generate gate ---

# writeCommandFiles emits only APPROVED adds and prunes, correctly -- an
# unapproved candidate is a proposal.  So generating while decisions are pending
# produces a package quietly missing them.  Refuse instead.
#
# GATE ON `total` ONLY.  `annotated_prune` counts every prune holding
# annotations, approved or not, so it is not a subset of `prune` and can exceed
# `total`: it answers "what is at stake", not "is a human still deciding".
# Blocking on it would refuse a release curation already approved.
sub assertGenerationAllowed {
  my ($class, $result, $force, $overlayPath) = @_;

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
            . "  " . ($overlayPath
                      || '$GUS_HOME/data/ApiCommonModel/Model/apollo/roster-overlay.txt') . "\n"
            . "-- then re-run.  Run with --force only if you accept the omission.\n";

  die $message;
}

# Reported separately from the gate above and NOT suppressed by --force or by a
# clean decision count: a run with zero pending decisions is the one most likely
# to be executed unread, and it can still hide human annotations.  Returns undef
# when nothing is at stake.
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

# --- The generation roster ---

# update + rename + APPROVED add_candidate, deduplicated and sorted.  A rename
# is named by its NEW abbrev -- the directory the package writes and the one
# Apollo is repointed at.
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

  # An --organism outside the roster would otherwise generate a smaller package,
  # or an empty one, and report success.  Say which.
  my @unknown = grep { !$byAbbrev{$_} } @$only;
  die "--organism named " . scalar(@unknown) . " abbrev(s) that are not in the\n"
    . "generation roster (update + rename + approved add): " . join(', ', @unknown) . "\n"
    . "A rename is named by its NEW abbrev.  An unapproved add candidate is not\n"
    . "in the roster and cannot be generated by naming it here.\n"
    if @unknown;

  my %want = map { $_ => 1 } @$only;
  return [map { $byAbbrev{$_} } grep { $want{$_} } sort keys %byAbbrev];
}

# The one refusal --force cannot override.  --force accepts omitted candidates
# and an empty update bucket; neither licenses a package with nothing in it.
# Unforced this cannot fire, since a non-empty update bucket guarantees a
# non-empty roster -- so reaching it means someone overrode that gate and got
# the outcome it warned about.
#
# Takes no $force argument, unlike the gates either side of it.  The asymmetry is
# deliberate: a $force parameter here reopens the hole this closes.
sub assertRosterNonEmpty {
  my ($class, $roster) = @_;

  return 1 if @$roster;

  die "refusing to --generate an empty package: the generation roster\n"
    . "(update + rename + approved add) has no organisms.\n"
    . "This is reachable only with --force, which overrode the empty-update-bucket\n"
    . "check above.  Generating would write empty command files and exit 0 -- the\n"
    . "silent empty release this tool exists to replace.\n";
}

# The command files must describe the package actually built: full-roster
# commands beside a partial package is how an Apollo organism gets repointed at
# a directory nobody generated.
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

# --- Rename resolution: the database first, assembly identity as a fallback ---

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

  # Case-sensitive throughout: abbrevs differing only in case are different
  # organisms, and collisions exist in the namespace, so a lc() anywhere in this
  # path silently merges two genomes.  Nothing here folds case.
  my @orphans = grep { !exists $portal->{$_} } sort keys %$live;

  return {renames => {}, mechanism => {}, unresolved => [], warnings => []}
    unless @orphans;

  # --- 1. the database, which is authoritative ------------------------------
  #
  # A reclassification changes public_abbrev and leaves the internal abbrev
  # alone, while Apollo's `directory` holds the public abbrev as of the release
  # that wrote it.  So an orphan naming an internal abbrev whose organism now
  # publishes under a different name IS that organism.
  #
  # NO FILTER on self-referential entries (internal eq public), deliberately: an
  # orphan can never look one up, since such an entry's key is itself a public
  # abbrev.  Filtering them would only suppress the duplicate warning below in
  # the one state that warrants it -- one organism's public abbrev equalling
  # another's internal.  The identity entries are inert.
  my %publicByInternal;
  foreach my $organism (values %$portal) {
    my $internal = $organism->{internal_abbrev};
    next unless defined $internal && length $internal;

    # No internal abbrev repeats today.  If one ever does, both readings are
    # equally defensible, so take neither.
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

    # Repointing onto an abbrev Apollo already holds is a merge: two organisms
    # would share one directory, which Apollo.pm refuses to load next release.
    # Decline, leaving the orphan a prune candidate a human judges.
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

  # No strain filter: an orphan is by definition absent from the portal, so the
  # only strain evidence is Apollo's commonName, which is GUI-editable and
  # therefore never matched on.  Rename.pm compares against every portal
  # organism instead, and the sequence comparison is what decides.
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

    # Two orphans matching one portal organism: Reconcile dies on that, so catch
    # it here where the cause can be named and the release can still report.
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
