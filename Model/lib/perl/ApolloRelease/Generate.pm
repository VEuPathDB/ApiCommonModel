package ApiCommonModel::Model::ApolloRelease::Generate;

use strict;
use warnings;

use JSON;
use File::Path qw(make_path);
use File::Copy qw(cp);
use File::Temp;

use ApiCommonModel::Model::ApolloRelease::Absolutize;

my $ABS  = 'ApiCommonModel::Model::ApolloRelease::Absolutize';

# canonical() so two runs produce byte-identical files: the release is diffed
# against the previous one by hand, and hash order noise would bury the real
# changes.  utf8() so encode() returns octets -- some organisms carry non-ASCII
# in a track key, and a character string makes `print` emit a "Wide character"
# warning.  Any stderr byte from a config producer is treated as proof its
# output is untrustworthy, so this module must not emit one either.
my $JSON = JSON->new->canonical->utf8;

# Exposed so a test can assert the encoder emits octets.
sub encodeJson {
  my ($class, $document) = @_;
  return $JSON->encode($document);
}

# Turns one portal organism into the directory Apollo reads.
#
# TWO ABBREVS, and confusing them is the easiest mistake here:
#   - the five track producers take the INTERNAL abbrev; they key
#     auto_generated/<abbrev>/ off it directly;
#   - jbrowseTracks takes the PUBLIC abbrev (`where public_abbrev = ?`);
#   - every output path, and Apollo's data directory, uses the PUBLIC abbrev --
#     that is the identity Apollo already holds.
# Case sensitive throughout; abbrevs differing only in case are distinct.
#
# Text producers are split into a pure function and a coderef seam so the rules
# run with no database, no GUS_HOME and no filesystem.

# Warnings are COLLECTED, never written to stderr: this module treats a child's
# stderr byte as proof of untrustworthy output, so it must not emit one itself
# for a recoverable skip.
my @WARNINGS;

sub warnings { return @WARNINGS }

# --- PURE: include URL -> the local filename Apollo will read it as ---

# First match wins, so rnaseqJunctions MUST precede rnaseq: both are generated
# for the same organism, and the wrong order writes one file's contents under
# the other's name -- a package that parses, loads, and shows the wrong tracks.
my @INCLUDE_NAMES = (
  [qr{apollo_gene_tracks\.conf$} => 'apollo_gene_tracks.conf'],
  [qr{functions\.conf$}          => 'functions.conf'],
  [qr{bindingSites\.conf$}       => 'bindingSites.conf'],
  [qr{tracks\.conf$}             => 'tracks.conf'],
  [qr{rnaseqJunctions}i          => 'rnaseqJunctions.json'],
  [qr{organismSpecific}i         => 'organismSpecific.json'],
  [qr{rnaseq}i                   => 'rnaseq.json'],
  [qr{chipseq}i                  => 'chipseq.json'],
  [qr{dnaseq}i                   => 'dnaseq.json'],
);

# Deliberately not carried: user-datasets-jbrowse is per-user data behind a
# session cookie Apollo does not have, and jbrowse_embed.conf styles JBrowse for
# a VEuPathDB gene page, where Apollo supplies its own chrome.
my @DROP_INCLUDES = (qr{user-datasets-jbrowse}, qr{jbrowse_embed\.conf$});

sub localNameForInclude {
  my ($class, $url) = @_;

  foreach my $rule (@INCLUDE_NAMES) {
    my ($pattern, $name) = @$rule;
    return $name if $url =~ $pattern;
  }

  return undef;
}

# --- PURE: the site's trackList.json -> Apollo's ---

# Three deliberate differences from what the site serves: include URLs rewritten
# to local filenames, refSeqs pointed at the local .fai, and tracks replaced with
# a single local IndexedFasta reference track.
#
# $extraIncludes is what the CALLER actually wrote and the skeleton does not
# name.  Deriving the include list from what was really produced is what makes
# "every include resolves to a file that exists" true by construction.
sub buildTrackList {
  my ($class, $trackList, $abbrev, $base, $extraIncludes) = @_;

  # Shallow copy, then replace every nested structure touched: a shared arrayref
  # would accumulate the previous organism's includes.
  my %built = %$trackList;

  my @includes;
  my %seen;

  URL: foreach my $url (@{$trackList->{include} || []}) {
    foreach my $drop (@DROP_INCLUDES) {
      next URL if $url =~ $drop;
    }

    my $name = $class->localNameForInclude($url);

    # Not fatal, never silent: jbrowseTracks grew an endpoint this tool cannot
    # fetch, and a human decides whether Apollo wants it.
    unless ($name) {
      push @WARNINGS, "$abbrev: unrecognised include '$url'; not carried into the package";
      next URL;
    }

    next if $seen{$name}++;
    push @includes, $name;
  }

  foreach my $name (@{$extraIncludes || []}) {
    next if $seen{$name}++;
    push @includes, $name;
  }

  $built{include} = \@includes;

  # Apollo owns its own copy of the genome; the site's pointed at a store URL.
  $built{refSeqs} = "seq/$abbrev.fa.fai";

  $built{names} = {%{$trackList->{names} || {}}};
  $built{names}{url} = $ABS->rewrite($built{names}{url}, $base)
    if defined $built{names}{url};

  $built{tracks} = [
    {
      category         => "Sequence Analysis",
      faiUrlTemplate   => "seq/$abbrev.fa.fai",
      key              => "Reference sequence",
      label            => "DNA",
      seqType          => "dna",
      storeClass       => "JBrowse/Store/SeqFeature/IndexedFasta",
      type             => "SequenceTrack",
      urlTemplate      => "seq/$abbrev.fa",
      useAsRefSeqStore => JSON::true,
    }
  ];

  return \%built;
}

# --- PURE: refSeqs.json derived from the .fai ---

# Derived from the .fai already in hand rather than from jbrowseRefSeqs, which
# is orphaned upstream.  Dies rather than warns on a malformed line: here the
# output IS the index, and half of one is a package missing sequences.
sub refSeqsFromFai {
  my ($class, $text) = @_;

  my @refSeqs;
  my $lineNumber = 0;

  foreach my $line (split /\n/, ($text // '')) {
    $lineNumber++;
    next unless length $line;

    my ($name, $length) = split /\t/, $line;

    die "malformed .fai line $lineNumber: '$line'\n"
      unless defined $name && length $name && defined $length && $length =~ /^\d+$/;

    # +0 so these encode as JSON numbers: JBrowse compares them arithmetically.
    push @refSeqs, {name => $name, start => 0, end => $length + 0, length => $length + 0};
  }

  return \@refSeqs;
}

# --- PURE: strip the store-URL reference track ---

# organismSpecific.json carries an IndexedFasta track pointing at the site's
# store URL; Apollo must use the local copy in seq/ instead, and two tracks both
# claiming to be the reference store is not a merge JBrowse resolves our way.
#
# Filter on the FIELD, never the label: the label is cosmetic, so renaming it
# would leave the store-URL track in place with nothing failing.
sub stripRefSeqStoreTracks {
  my ($class, $document) = @_;

  my %copy = %$document;
  my @kept;
  my $removed = 0;

  foreach my $track (@{$document->{tracks} || []}) {
    if (ref $track eq 'HASH' && $track->{useAsRefSeqStore}) {
      $removed++;
      next;
    }
    push @kept, $track;
  }

  $copy{tracks} = \@kept;

  return (\%copy, $removed);
}

# --- PURE: invariants over a generated tracks array ---

# Track builders upstream have pushed bare integers onto this array.  The JSON
# stays valid, so nothing notices before a curator's browser; this is the last
# gate before the package ships and the check costs one pass.
sub assertTracksAreObjects {
  my ($class, $document, $label) = @_;

  die "$label: expected a 'tracks' array\n"
    unless ref($document->{tracks} || []) eq 'ARRAY';

  my @bad;
  my $tracks = $document->{tracks} || [];

  for (my $i = 0; $i < @$tracks; $i++) {
    push @bad, $i unless ref $tracks->[$i] eq 'HASH';
  }

  return 1 unless @bad;

  my @shown = @bad > 5 ? @bad[0 .. 4] : @bad;
  die "$label: " . scalar(@bad) . " of " . scalar(@$tracks)
    . " entries in 'tracks' are not JSON objects, at index(es) "
    . join(', ', @shown) . (@bad > @shown ? ', ...' : '') . "\n";
}

# Zero is a COUNT, not a failure: an organism with no such data loaded really
# has no tracks.  Failing would block a correct release, hiding it would let
# empty-but-valid output through unseen, so the caller records it for a human.
sub countTracks {
  my ($class, $document) = @_;
  return scalar @{$document->{tracks} || []};
}

# --- PURE: strip the [tracks.refseq] stanza from a tracks.conf ---

# Same reason as stripRefSeqStoreTracks: a second declaration of the reference
# store is at best redundant and at worst wins.
#
# A no-op across the current roster, implemented anyway: the stanza comes from
# the model, so it can return in any build, and an unimplemented requirement
# reads to the next reader exactly like a forgotten one.  The count is returned
# so a re-appearance is reported rather than absorbed.
#
# Line based, not a regex: a character class stopping at "#" leaves the tail of
# the stanza behind, and tracks.conf is full of commented-out keys.
sub stripRefSeqStanza {
  my ($class, $text) = @_;

  return ($text, 0) unless defined $text;

  my @kept;
  my $removed  = 0;
  my $inStanza = 0;

  # -1 limit so a trailing newline survives the rejoin.
  foreach my $line (split /\n/, $text, -1) {
    if ($line =~ /^\s*\[tracks\.refseq\]\s*$/) {
      $inStanza = 1;
      $removed++;
      next;
    }

    # A stanza runs to the next section header or EOF; blanks and comments
    # inside it belong to it.
    $inStanza = 0 if $inStanza && $line =~ /^\s*\[/;

    push @kept, $line unless $inStanza;
  }

  return (join("\n", @kept), $removed);
}

# --- IO: write one file, absolutized, with the post-condition enforced ---

sub writeFile {
  my ($class, $path, $content, $base) = @_;

  my $rewritten = $ABS->rewrite($content, $base);

  # Not optional: a missed URL is a track that 404s inside Apollo, so the config
  # loads, the track appears, and it is empty.
  $ABS->assertNoRelative($rewritten, $path);

  # ':raw' deliberately -- every producer hands this octets already, so an
  # encoding layer here would be a second, wrong one.
  open(my $fh, '>:raw', $path) or die "Cannot write $path: $!\n";
  print $fh $rewritten;
  close $fh or die "Cannot close $path: $!\n";

  return 1;
}

# --- The seams: everything that shells out or touches disk ---

# Runs one of the jbrowse* producers and returns its stdout.  ANY byte on stderr
# is fatal: these scripts are also served through responseFromCommand, which
# merges stderr into the response body, so the JSON about to be parsed may be
# the warning text spliced into it.
sub _defaultRunScript {
  my ($gusHome, $script, @args) = @_;

  my $errFile = File::Temp->new(TEMPLATE => 'apolloRelease.XXXXXXXX',
                                TMPDIR   => 1, SUFFIX => '.err');

  my $quoted = join ' ', map { "'" . (s/'/'\\''/gr) . "'" } @args;
  my $cmd = "$gusHome/bin/$script $quoted";

  my $out = `$cmd 2>'$errFile'`;

  if ($?) {
    $errFile->unlink_on_destroy(0);
    die "$script failed (exit " . ($? >> 8) . "); see $errFile\n";
  }

  my $errSize = -s "$errFile" || 0;
  if ($errSize) {
    $errFile->unlink_on_destroy(0);
    die "$script wrote $errSize bytes to stderr; refusing to trust its output.\n"
      . "See $errFile\n";
  }

  return $out;
}

sub _defaultReadFile {
  my ($path) = @_;
  open(my $fh, '<', $path) or die "Cannot read $path: $!\n";
  local $/;
  my $content = <$fh>;
  close $fh;
  return $content;
}

sub _defaultCopyFile {
  my ($from, $to) = @_;
  cp($from, $to) or die "Cannot copy $from to $to: $!\n";
  return 1;
}

sub _defaultTwoBit {
  my ($fasta, $out) = @_;
  system('faToTwoBit', $fasta, $out) == 0
    or die "faToTwoBit $fasta $out failed: $?\n";
  return 1;
}

# DELIBERATELY NOT CALLED FROM THIS MODULE: generateOrganism runs once per
# organism, so a check here would repeat per organism or become the late
# failure it exists to prevent, and a caller substituting the `twoBit` seam has
# no use for faToTwoBit.  The CLI calls it once before the loop.  Tested here so
# "uncalled" cannot quietly become "unverified".
sub assertToolsAvailable {
  my ($class) = @_;

  my $found = `which faToTwoBit 2>/dev/null`;
  chomp $found;

  die "faToTwoBit is not on PATH.\n"
    . "Install UCSC's current linux.x86_64 build to ~/bin/faToTwoBit.\n"
    . "(The 2016 copy at /eupath/workflow-software/bin/faToTwoBit links against\n"
    . " libssl.so.10 and does not run on cedar.)\n"
    unless $found && -x $found;

  return $found;
}

# --- One organism, end to end ---

# Table driven because the argument ORDER differs per script for no reason
# anyone remembers, and five near-identical inline call sites is how one ends up
# with the build number where the wsDir goes.
my @TRACK_SOURCES = (
  {file => 'rnaseq.json',           script => 'jbrowseRnaAndChipSeqTracks',
   args  => sub { my ($i, $o) = @_; ($i, $o->{project}, $o->{build}, $o->{wsDir}, 'RNASeq', 'jbrowse') }},
  {file => 'chipseq.json',          script => 'jbrowseRnaAndChipSeqTracks',
   args  => sub { my ($i, $o) = @_; ($i, $o->{project}, $o->{build}, $o->{wsDir}, 'ChIPSeq', 'jbrowse') }},
  {file => 'rnaseqJunctions.json',  script => 'jbrowseRNASeqJunctionTracks',
   args  => sub { my ($i, $o) = @_; ($i, $o->{project}, $o->{build}, $o->{wsDir}, 1, 'jbrowse') }},
  {file => 'organismSpecific.json', script => 'jbrowseOrganismSpecificTracks',
   args  => sub { my ($i, $o) = @_; ($i, $o->{project}, 1, $o->{build}, $o->{wsDir}, 'jbrowse') }},
  {file => 'dnaseq.json',           script => 'jbrowseDNASeqTracks',
   args  => sub { my ($i, $o) = @_; ($i, $o->{project}, $o->{build}, $o->{wsDir}, 'jbrowse') }},
);

# Static config copied verbatim (after absolutization) into every organism dir.
# apollo_gene_tracks.conf is checked in, not generated, and defines the
# draggable annotation track curators drag genes INTO -- the reason Apollo
# exists -- so it ships for every organism the roster admits.
my @STATIC_CONFIGS = (
  {file => 'functions.conf',          from => sub { "$_[0]/lib/jbrowse/functions.conf" }},
  {file => 'apollo_gene_tracks.conf', from => sub { "$_[0]/lib/jbrowse/apollo_gene_tracks.conf" }},
);

# $organism  - a Portal.pm organism (needs abbrev, internal_abbrev, name_for_filenames)
# %$opts     - outDir, base, project, build, wsDir, gusHome, plus optional seams:
#              runScript($gusHome, $script, @args) -> stdout
#              readFile($path) -> text
#              copyFile($from, $to)
#              twoBit($fasta, $out)
sub generateOrganism {
  my ($class, $organism, $opts) = @_;

  my $abbrev   = $organism->{abbrev}
    or die "organism has no public abbrev\n";
  my $internal = $organism->{internal_abbrev} || $abbrev;
  my $files    = $organism->{name_for_filenames}
    or die "$abbrev: no name_for_filenames; cannot locate its webServices genome\n";

  my $runScript = $opts->{runScript} || \&_defaultRunScript;
  my $readFile  = $opts->{readFile}  || \&_defaultReadFile;
  my $copyFile  = $opts->{copyFile}  || \&_defaultCopyFile;
  my $twoBit    = $opts->{twoBit}    || \&_defaultTwoBit;

  my $base    = $opts->{base};
  my $gusHome = $opts->{gusHome};

  my $organismDir = "$opts->{outDir}/data/$abbrev";
  my $seqDir      = "$organismDir/seq";
  # Under data/, not beside it: the container mounts data/ as /data/apollo_data,
  # so a sibling twoBit/ is unreachable from the blatdb paths Commands.pm emits.
  my $twoBitDir   = "$opts->{outDir}/data/twoBit";
  make_path($seqDir, $twoBitDir);

  my %summary = (abbrev => $abbrev, internal_abbrev => $internal,
                 counts => {}, empty => [], stripped => 0);

  # --- the five generated track files -------------------------------------
  my @generated;
  foreach my $source (@TRACK_SOURCES) {
    my @args = $source->{args}->($internal, $opts);
    my $json = $runScript->($gusHome, $source->{script}, @args);

    my $document = eval { decode_json($json) };
    die "$abbrev: $source->{script} did not return JSON for $source->{file}\n"
      unless $document;

    $class->assertTracksAreObjects($document, "$abbrev/$source->{file}");

    if ($source->{file} eq 'organismSpecific.json') {
      my $removed;
      ($document, $removed) = $class->stripRefSeqStoreTracks($document);
      $summary{stripped} = $removed;

      # Exactly one expected: zero means the strip has become a no-op, more
      # means something changed shape.  Neither is fatal, both want a human.
      push @WARNINGS, "$abbrev: organismSpecific.json had $removed useAsRefSeqStore "
        . "track(s); expected exactly 1"
        unless $removed == 1;
    }

    my $count = $class->countTracks($document);
    $summary{counts}{$source->{file}} = $count;
    push @{$summary{empty}}, $source->{file} unless $count;

    $class->writeFile("$organismDir/$source->{file}", $class->encodeJson($document), $base);
    push @generated, $source->{file};
  }

  # --- tracks.conf, keyed off the INTERNAL abbrev -------------------------
  my ($tracksConf, $stanzas) = $class->stripRefSeqStanza(
    $readFile->("$gusHome/lib/jbrowse/auto_generated/$internal/tracks.conf"));

  # Currently zero rosterwide (see stripRefSeqStanza).  Say so if that changes:
  # the model started emitting a reference store again and someone must decide
  # whether Apollo still wants it gone.
  push @WARNINGS, "$abbrev: tracks.conf carried $stanzas [tracks.refseq] stanza(s), "
    . "which were stripped; this has been a no-op for the whole roster since 2026-08-21"
    if $stanzas;

  $summary{refseq_stanzas_stripped} = $stanzas;

  $class->writeFile("$organismDir/tracks.conf", $tracksConf, $base);
  push @generated, 'tracks.conf';

  # --- static config ------------------------------------------------------
  foreach my $static (@STATIC_CONFIGS) {
    $class->writeFile("$organismDir/$static->{file}",
                      $readFile->($static->{from}->($gusHome)), $base);
    push @generated, $static->{file};
  }

  # --- the genome, its index, and refSeqs.json ----------------------------
  # Copied VERBATIM, not through writeFile: absolutizing tens of megabytes of
  # nucleotides finds nothing, and the .fai carries no self-reference.
  my $fastaSource = "$opts->{wsDir}/$opts->{project}/build-$opts->{build}"
                  . "/$files/genomeAndProteome/fasta/genome.fasta";

  $copyFile->($fastaSource,          "$seqDir/$abbrev.fa");
  $copyFile->("$fastaSource.fai",    "$seqDir/$abbrev.fa.fai");

  my $refSeqs = $class->refSeqsFromFai($readFile->("$seqDir/$abbrev.fa.fai"));
  die "$abbrev: the copied .fai describes no sequences\n" unless @$refSeqs;

  $class->writeFile("$seqDir/refSeqs.json", $class->encodeJson($refSeqs), $base);
  $summary{sequences} = scalar @$refSeqs;

  # --- .2bit for BLAT -----------------------------------------------------
  # Always regenerated: it is sub-second per genome, and an incremental scheme
  # keyed on genome version adds state to save nothing.
  $twoBit->("$seqDir/$abbrev.fa", "$twoBitDir/$abbrev.2bit");

  # --- trackList.json, last, naming exactly what was written --------------
  # jbrowseTracks takes the PUBLIC abbrev.
  my $skeleton = decode_json($runScript->($gusHome, 'jbrowseTracks',
                                          $abbrev, $opts->{project}, 0, 'geneAnnotationTracks'));

  my $trackList = $class->buildTrackList($skeleton, $abbrev, $base, \@generated);
  $class->writeFile("$organismDir/trackList.json", $class->encodeJson($trackList), $base);

  $summary{includes} = $trackList->{include};

  return \%summary;
}

# --- The whole roster, with failures isolated ---

# The organisms are independent and the run is hours long, so a failure is
# recorded and the loop continues rather than discarding completed work.  The
# caller exits non-zero on any entry in {failed}.
sub generateAll {
  my ($class, $organisms, $perOrganism) = @_;

  @WARNINGS = ();

  my %results = (succeeded => [], failed => [], errors => {}, summaries => {});

  foreach my $organism (@$organisms) {
    my $abbrev = $organism->{abbrev};

    my $summary = eval { $perOrganism->($organism) };

    if (defined $summary) {
      push @{$results{succeeded}}, $abbrev;
      $results{summaries}{$abbrev} = $summary;
    }
    else {
      my $error = $@ || "returned nothing and set no error";
      chomp $error;
      push @{$results{failed}}, $abbrev;
      $results{errors}{$abbrev} = $error;
    }
  }

  return \%results;
}

1;
