package ApiCommonModel::Model::ApolloRelease::Generate;

use strict;
use warnings;

use JSON;
use File::Path qw(make_path);
use File::Copy qw(cp);
use File::Temp;

use ApiCommonModel::Model::ApolloRelease::Absolutize;

my $ABS  = 'ApiCommonModel::Model::ApolloRelease::Absolutize';

# canonical() so two runs over the same model produce byte-identical files.
# The release is diffed against the previous one by hand; hash order noise
# would bury the handful of real changes in a few hundred thousand lines.
#
# utf8() so encode() returns OCTETS, not characters.  decode_json hands back
# decoded characters, and several organisms carry non-ASCII in a track key or
# description (tgonME49 does), so encoding without this produces a character
# string that `print` emits with a "Wide character" warning.  The bytes on disk
# would have been right; the warning is the problem -- this module's own policy
# (_defaultRunScript, Portal.pm) is that any stderr byte from a config producer
# means its output is untrustworthy, and these files are also served through
# responseFromCommand, which splices stderr into the JSON body.
my $JSON = JSON->new->canonical->utf8;

# Exposed so a test can assert the encoder really emits octets.  Everything
# this module writes goes through it.
sub encodeJson {
  my ($class, $document) = @_;
  return $JSON->encode($document);
}

# Turns one portal organism into the directory Apollo reads.
#
# TWO ABBREVS, and mixing them up is the single easiest mistake here.  See
# Portal.pm: `abbrev` is public_abbrev, `internal_abbrev` is apidb.organism.abbrev,
# and they differ for 37 of 831 organisms.
#   - the five track-producing scripts take the INTERNAL abbrev, because they
#     key auto_generated/<abbrev>/ off it directly (a wrong one is exit 2 on a
#     missing datasetAndPresenterProps.conf);
#   - jbrowseTracks takes the PUBLIC abbrev (its SQL is `where public_abbrev = ?`);
#   - every output path, and Apollo's own data directory, uses the PUBLIC abbrev,
#     because that is the identity Apollo already holds for the organism.
# Comparisons are case sensitive throughout: scerS288C and scerS288c are two
# different organisms.
#
# Everything that produces text is split into a pure function and a seam, so
# the rules can be exercised with no database, no GUS_HOME and no filesystem.
# The seams are coderefs in %opts, in the style Rename.pm uses for its .fai
# lookups.

# Warnings are COLLECTED, never written to stderr -- same policy as Portal.pm
# and Rename.pm.  These scripts are also served through responseFromCommand,
# which merges stderr into the JSON body, so this module treats a child's
# stderr as proof its output is untrustworthy; it must not then emit stderr of
# its own for a recoverable skip.
my @WARNINGS;

sub warnings { return @WARNINGS }

# ---------------------------------------------------------------------------
# PURE: include URL -> the local filename Apollo will read it as
# ---------------------------------------------------------------------------

# Ordered: the first match wins.  rnaseqJunctions MUST precede rnaseq -- both
# endpoints are generated for the same organism, so the wrong order writes one
# file's contents under the other's name, producing a package that parses, and
# loads, and shows the wrong tracks.
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

# Includes that are deliberately NOT carried into the package.
#   user-datasets-jbrowse: per-user data behind a session cookie.  Apollo has no
#     session, so the include would 404 on every load.
#   jbrowse_embed.conf: styling for JBrowse embedded in a VEuPathDB gene page.
#     Apollo embeds JBrowse itself and supplies its own chrome; release-68 never
#     carried it, because Paul's script read the DEFAULT jbrowseTracks track set,
#     which does not name it.
my @DROP_INCLUDES = (qr{user-datasets-jbrowse}, qr{jbrowse_embed\.conf$});

sub localNameForInclude {
  my ($class, $url) = @_;

  foreach my $rule (@INCLUDE_NAMES) {
    my ($pattern, $name) = @$rule;
    return $name if $url =~ $pattern;
  }

  return undef;
}

# ---------------------------------------------------------------------------
# PURE: the site's trackList.json -> Apollo's
# ---------------------------------------------------------------------------

# Three deliberate differences from what the site serves, all declared in spec
# section 10 so that a diff against the live site can be audited:
#   1. include URLs rewritten to the local filenames (and the drops above)
#   2. refSeqs pointed at the local .fai
#   3. tracks replaced with a single local IndexedFasta reference track
#
# $extraIncludes is the set of files the CALLER actually wrote and that the
# skeleton does not name -- functions.conf and apollo_gene_tracks.conf are
# pushed on by this tool, not by jbrowseTracks, and with the geneAnnotationTracks
# skeleton so are rnaseq/chipseq/dnaseq.  Deriving the include list from what
# was really produced is what makes "every include resolves to a file that
# exists and parses" true by construction rather than by inspection.
sub buildTrackList {
  my ($class, $trackList, $abbrev, $base, $extraIncludes) = @_;

  # Shallow copy, then replace every nested structure we touch.  generateAll
  # runs this once per organism and a shared nested arrayref would accumulate
  # the previous organism's includes.
  my %built = %$trackList;

  my @includes;
  my %seen;

  URL: foreach my $url (@{$trackList->{include} || []}) {
    foreach my $drop (@DROP_INCLUDES) {
      next URL if $url =~ $drop;
    }

    my $name = $class->localNameForInclude($url);

    # Not fatal, but never silent.  An unmapped include means jbrowseTracks
    # grew an endpoint this tool does not know how to fetch; the package is
    # still usable, and a human needs to decide whether Apollo wants it.
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

  # Apollo owns its own copy of the genome; the site's refSeqs pointed at a
  # store URL.
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

# ---------------------------------------------------------------------------
# PURE: refSeqs.json derived from the .fai
# ---------------------------------------------------------------------------

# NOT from jbrowseRefSeqs, which is orphaned: both service endpoints that
# called it are commented out, and it has died with a missing getCacheFile for
# every organism since commit e0e9a61bb.  The .fai we already copy carries the
# same two facts, so this is one extra pass over a file in hand instead of a
# per-organism database round trip.
#
# Dies rather than warns on a malformed line.  Rename.pm can afford to shrug at
# a bad index (the organism just stays a prune candidate); here the output IS
# the index, and half of one is a package that loads with sequences missing.
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

    # +0 so these encode as JSON numbers.  JBrowse compares them
    # arithmetically, and a quoted "1876705" sorts as a string.
    push @refSeqs, {name => $name, start => 0, end => $length + 0, length => $length + 0};
  }

  return \@refSeqs;
}

# ---------------------------------------------------------------------------
# PURE: strip the store-URL reference track
# ---------------------------------------------------------------------------

# Every organism's organismSpecific.json carries one IndexedFasta track with
# useAsRefSeqStore true, pointing at the site's store URL.  Apollo must use the
# local copy this tool writes into seq/ instead; two tracks both claiming to be
# the reference sequence store is not a merge JBrowse resolves in our favour.
#
# Filter on the FIELD, never on the label.  The label ("refseqs") is cosmetic:
# one organism's presenter renaming it would leave the store-URL track in place
# with nothing failing.
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

# ---------------------------------------------------------------------------
# PURE: invariants over a generated tracks array
# ---------------------------------------------------------------------------

# A bug fixed on master today had addChipChipTracks pushing bare integers onto
# the tracks array -- 56 of 158 entries for tgonME49.  The JSON stayed valid,
# so nothing upstream of a curator's browser noticed.  This module is the last
# gate before the package ships, and the check costs one pass.
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

# Zero is a COUNT, not a failure.  cneoJEC21 genuinely has 0 ChIP-Seq and 0
# DNA-Seq tracks: its datasetAndPresenterProps.conf carries the template
# anchors with no injected entries beneath them, because no such data is
# loaded.  Failing on it would block a correct release; hiding it would let the
# flat-file migration's characteristic empty-but-valid output through unseen.
# So the caller records it and a human judges.
sub countTracks {
  my ($class, $document) = @_;
  return scalar @{$document->{tracks} || []};
}

# ---------------------------------------------------------------------------
# PURE: strip the [tracks.refseq] stanza from a tracks.conf
# ---------------------------------------------------------------------------

# Same reason as stripRefSeqStoreTracks: Apollo reads its own local copy of the
# genome out of seq/, so a second declaration of the reference sequence store
# is at best redundant and at worst wins.
#
# CENSUS, 2026-08-21 (cedar, build 71, GUS_HOME eupathdb.jbrestel):
#   835 auto_generated/<abbrev>/tracks.conf files
#     0 contain "[tracks.refseq]"
#     0 contain the substring "refseq" at all, case-insensitively
# So this is a NO-OP today -- over the entire roster, not the four-organism
# sample the spec baseline used and warned not to generalise from.  It is
# implemented anyway, deliberately:
#   - spec section 6 states the requirement, and an unimplemented stated
#     requirement is indistinguishable to the next reader from a forgotten one.
#     That is exactly how the script this replaces accumulated its dead
#     branches;
#   - the stanza is emitted by the model, not by this tool, so it can come back
#     in any build without a line here changing;
#   - it costs one pass over a 35KB file.
# The count is returned so the caller can report a re-appearance rather than
# silently absorb it.
#
# Line based rather than Paul's `s/\[tracks.refseq\][^#\[]*//`, whose character
# class stops at the first "#" -- and tracks.conf is full of commented-out keys,
# so that regex leaves the tail of the stanza behind whenever one contains a
# comment.
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

    # A stanza runs to the next section header, or to end of file.  Blank
    # lines and comments inside it belong to it.
    $inStanza = 0 if $inStanza && $line =~ /^\s*\[/;

    push @kept, $line unless $inStanza;
  }

  return (join("\n", @kept), $removed);
}

# ---------------------------------------------------------------------------
# IO: write one file, absolutized, with the post-condition enforced
# ---------------------------------------------------------------------------

sub writeFile {
  my ($class, $path, $content, $base) = @_;

  my $rewritten = $ABS->rewrite($content, $base);

  # Not optional.  The previous script did the same rewrite with no check, so a
  # missed URL became a track that 404s inside Apollo: the config loads, the
  # track appears, and it is empty.
  $ABS->assertNoRelative($rewritten, $path);

  # ':raw' deliberately: every producer above hands this octets already (the
  # JSON encoder is utf8(), the .conf files are slurped as bytes), so any
  # encoding layer here would be a second, wrong one.
  open(my $fh, '>:raw', $path) or die "Cannot write $path: $!\n";
  print $fh $rewritten;
  close $fh or die "Cannot close $path: $!\n";

  return 1;
}

# ---------------------------------------------------------------------------
# The seams: everything that shells out or touches disk
# ---------------------------------------------------------------------------

# Runs one of the jbrowse* producers and returns its stdout.
#
# ANY byte on stderr is fatal, matching Portal.pm.  These scripts are also
# served through responseFromCommand, which merges stderr into the response
# body, so a stray Perl warning is a correctness bug rather than a log line --
# and the JSON we are about to parse may be the warning text spliced into it.
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

# Checked once, at startup, not 400 organisms into a run.
#
# DELIBERATELY NOT CALLED FROM THIS MODULE.  generateOrganism is invoked once
# per organism, so a check here would either run 831 times or be the 400th
# organism's problem; and a caller substituting the `twoBit` seam has no use
# for faToTwoBit at all.  The CLI (task 12) calls this once before the loop.
# It is tested here so that "uncalled" cannot quietly become "unverified".
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

# ---------------------------------------------------------------------------
# One organism, end to end
# ---------------------------------------------------------------------------

# The five track producers, each with the argv jbrowse* expects.  Table driven
# because the argument ORDER differs per script for no reason anyone remembers,
# and inlining five near-identical call sites is how one of them ends up with
# the build number where the wsDir goes.
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
#
# apollo_gene_tracks.conf is NOT generated by anything: it is a checked-in file,
# ApiCommonModel/Model/lib/jbrowse/apollo_gene_tracks.conf, installed to
# $GUS_HOME/lib/jbrowse/ and separately to the webapp by ApiCommonWebsite's
# build.xml.  It defines [tracks.processed_transcripts] -- category "Draggable
# Annotation" -- which is the track curators drag genes INTO.  It is the reason
# Apollo exists, so it ships for every organism in the roster.  Paul's "TODO:
# only include this for annotated genomes" is already satisfied upstream of
# here: Portal::qualifies admits only reference AND annotated genomes.
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
  my $twoBitDir   = "$opts->{outDir}/twoBit";
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

      # Exactly one is expected.  Zero means the site stopped emitting it and
      # this strip has quietly become a no-op; more than one means something
      # changed shape.  Neither is fatal -- Apollo's own local track is what
      # the package uses either way -- but both want a human.
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

  # Zero for all 835 organisms as of 2026-08-21 (see stripRefSeqStanza).  Say
  # so if that changes, because it means the model started emitting a reference
  # store again and someone should decide whether Apollo still wants it gone.
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
  # Copied VERBATIM, not through writeFile: this is sequence data, an
  # absolutization pass over 67MB of nucleotides would find nothing and cost
  # real time, and the .fai carries no self-reference so renaming it is safe.
  my $fastaSource = "$opts->{wsDir}/$opts->{project}/build-$opts->{build}"
                  . "/$files/genomeAndProteome/fasta/genome.fasta";

  $copyFile->($fastaSource,          "$seqDir/$abbrev.fa");
  $copyFile->("$fastaSource.fai",    "$seqDir/$abbrev.fa.fai");

  my $refSeqs = $class->refSeqsFromFai($readFile->("$seqDir/$abbrev.fa.fai"));
  die "$abbrev: the copied .fai describes no sequences\n" unless @$refSeqs;

  $class->writeFile("$seqDir/refSeqs.json", $class->encodeJson($refSeqs), $base);
  $summary{sequences} = scalar @$refSeqs;

  # --- .2bit for BLAT -----------------------------------------------------
  # Always regenerated, never copied forward: 0.17-0.74s per genome, and an
  # incremental scheme keyed on genome version adds state to save nothing.
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

# ---------------------------------------------------------------------------
# The whole roster, with failures isolated
# ---------------------------------------------------------------------------

# Paul's script died on the first missing input, discarding hours of completed
# work.  The organisms are independent and the run is hours long, so a failure
# is recorded and the loop continues; the caller exits non-zero on any entry in
# {failed}.
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
