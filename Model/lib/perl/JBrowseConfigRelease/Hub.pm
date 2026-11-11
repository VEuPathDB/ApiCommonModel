package ApiCommonModel::Model::JBrowseConfigRelease::Hub;

use strict;
use warnings;

use JSON;
use File::Path qw(make_path);
use File::Temp;
use Digest::MD5;
use Time::HiRes;
use URI::Escape;

use ApiCommonModel::Model::JBrowseConfigRelease::Generate;
use ApiCommonModel::Model::JBrowseConfigRelease::Validate;

# The JBrowse 2 v5 dump (decision 0007): per project a root config declaring every
# organism's genome and protein assembly, no tracks, and the URL template
# VEuPathDBSite resolves each organism's hub from; an organism list for the
# picker; and per organism a hub (a JBrowse 2 config.json read by
# JB2TrackHubConnection) holding that organism's assemblies and tracks.
#
# Builders are pure; producers, files and the jbrowse CLI sit behind seams.

my $GENERATE = 'ApiCommonModel::Model::JBrowseConfigRelease::Generate';
my $VALIDATE = 'ApiCommonModel::Model::JBrowseConfigRelease::Validate';

my $JSON = JSON->new->canonical->utf8->pretty;

our $STORE_PREFIX = '/a/service/jbrowse/store?data=';

# Where the dump's own files live under <wsDir>/<project>/build-<n>/.
our $MIRROR_SUBDIR = 'jbrowse2';

our $GENE_MODELS_LABEL = 'GeneModels';

# The jbrowse2 producers, run with the INTERNAL abbrev as JBrowseService runs them.
our @TRACK_SOURCES = (
  {name => 'rnaseq',           script => 'jbrowseRnaAndChipSeqTracks',
   args => sub { my ($i, $o) = @_; ($i, $o->{project}, $o->{build}, $o->{wsDir}, 'RNASeq', 'jbrowse2') }},
  {name => 'chipseq',          script => 'jbrowseRnaAndChipSeqTracks',
   args => sub { my ($i, $o) = @_; ($i, $o->{project}, $o->{build}, $o->{wsDir}, 'ChIPSeq', 'jbrowse2') }},
  {name => 'rnaseqJunctions',  script => 'jbrowseRNASeqJunctionTracks',
   args => sub { my ($i, $o) = @_; ($i, $o->{project}, $o->{build}, $o->{wsDir}, 0, 'jbrowse2') }},
  {name => 'organismSpecific', script => 'jbrowseOrganismSpecificTracks',
   args => sub { my ($i, $o) = @_; ($i, $o->{project}, 0, $o->{build}, $o->{wsDir}, 'jbrowse2') }},
  {name => 'dnaseq',           script => 'jbrowseDNASeqTracks',
   args => sub { my ($i, $o) = @_; ($i, $o->{project}, $o->{build}, $o->{wsDir}, 'jbrowse2') }},
  {name => 'organismSpecificPbrowse', script => 'jbrowseOrganismSpecificPbrowseTracks',
   args => sub { my ($i, $o) = @_; ($i, $o->{project}, $o->{build}, $o->{wsDir}, 'jbrowse2') }},
);

sub encodeJson {
  my ($class, $document) = @_;
  return $JSON->encode($document);
}

# --- PURE: locations ---

sub storeUrl {
  my ($class, $path) = @_;
  return $STORE_PREFIX . uri_escape_utf8($path, '^A-Za-z0-9\-._~/');
}

sub defaultArtifactUrlBase {
  my ($class) = @_;
  return $class->storeUrl("$MIRROR_SUBDIR/");
}

sub mirrorPath {
  my ($class, $opts, $file) = @_;
  return "$opts->{wsDir}/$opts->{project}/build-$opts->{build}/$MIRROR_SUBDIR/$file";
}

sub _uriLocation { return {uri => $_[0], locationType => 'UriLocation'} }

sub genomeFastaPath  { "$_[1]->{name_for_filenames}/genomeAndProteome/fasta/genome.fasta" }
sub proteinFastaPath { "$_[1]->{name_for_filenames}/genomeAndProteome/fasta/AnnotatedProteins.fasta" }
sub geneGffPath      { "$_[1]->{name_for_filenames}/genomeAndProteome/gff/annotated_transcripts.gff.gz" }

sub proteinAssemblyName { return "$_[1]->{abbrev}_protein" }

# --- PURE: assemblies ---

sub _fastaAssembly {
  my ($class, $name, $displayName, $path, %sequence) = @_;

  my $url = $class->storeUrl($path);
  return {
    name        => $name,
    displayName => $displayName,
    sequence    => {
      type    => 'ReferenceSequenceTrack',
      trackId => "${name}_refseq",
      %sequence,
      adapter => {
        type          => 'IndexedFastaAdapter',
        fastaLocation => _uriLocation($url),
        faiLocation   => _uriLocation("$url.fai"),
      },
    },
  };
}

sub genomeAssembly {
  my ($class, $organism) = @_;
  return $class->_fastaAssembly($organism->{abbrev}, $organism->{name},
                                $class->genomeFastaPath($organism));
}

sub proteinAssembly {
  my ($class, $organism) = @_;
  return $class->_fastaAssembly($class->proteinAssemblyName($organism),
                                "$organism->{name} (proteins)",
                                $class->proteinFastaPath($organism),
                                sequenceType => 'pep');
}

# An organism with no annotation has no proteome, so no protein assembly.
sub assembliesFor {
  my ($class, $organism) = @_;
  my @assemblies = ($class->genomeAssembly($organism));
  push @assemblies, $class->proteinAssembly($organism) if($organism->{is_annotated});
  return @assemblies;
}

# --- PURE: the three documents ---

sub hubFile { return "$_[1].hub.json" }

# VEuPathDBSite substitutes {abbrev} itself, so the placeholder must reach it
# unescaped: never route the template through storeUrl.
sub hubUrlTemplate {
  my ($class, $artifactUrlBase) = @_;
  die "hubUrlTemplate needs the artifact URL base\n"
    unless(defined $artifactUrlBase && length $artifactUrlBase);
  return $artifactUrlBase . $class->hubFile('{abbrev}');
}

sub rootConfig {
  my ($class, $organisms, $artifactUrlBase) = @_;
  my @assemblies = sort { $a->{name} cmp $b->{name} }
                   map { $class->assembliesFor($_) } @$organisms;
  return {assemblies    => \@assemblies,
          configuration => {VEuPathDBSite => {hubUrlTemplate => $class->hubUrlTemplate($artifactUrlBase)}}};
}

sub organismList {
  my ($class, $organisms) = @_;
  return [map { {abbrev      => $_->{abbrev},
                 displayName => $_->{name},
                 genus       => $_->{genus},
                 species     => $_->{species},
                 strain      => $_->{strain}} }
          sort { $a->{abbrev} cmp $b->{abbrev} } @$organisms];
}

sub geneModelsTrackId {
  my ($class, $organism) = @_;
  return "$organism->{abbrev}_$GENE_MODELS_LABEL";
}

sub trixFiles {
  my ($class, $trackId) = @_;
  return ("trix/$trackId.ix", "trix/$trackId.ixx");
}

sub textSearchAdapter {
  my ($class, $trackId, $assemblyName, $artifactUrlBase) = @_;
  my ($ix, $ixx) = $class->trixFiles($trackId);
  return {
    type          => 'TrixTextSearchAdapter',
    ixFilePath    => _uriLocation($artifactUrlBase . $ix),
    ixxFilePath   => _uriLocation($artifactUrlBase . $ixx),
    assemblyNames => [$assemblyName],
  };
}

# Track-level, not aggregate: a hub attached by JB2TrackHubConnection contributes
# only its tracks (and assemblies the session lacks), never top-level adapters.
sub hubConfig {
  my ($class, $organism, $tracks, $artifactUrlBase) = @_;

  my $geneTrackId = $class->geneModelsTrackId($organism);
  my @sorted = sort { $a->{trackId} cmp $b->{trackId} } @$tracks;

  my $indexed = 0;
  foreach my $track (@sorted) {
    next unless($track->{trackId} eq $geneTrackId);
    $track->{textSearching} = {textSearchAdapter =>
      $class->textSearchAdapter($geneTrackId, $organism->{abbrev}, $artifactUrlBase)};
    $indexed++;
  }

  return ({assemblies => [$class->assembliesFor($organism)], tracks => \@sorted}, $indexed);
}

# Validator over the hub, accepting the artifact base as a location only when it is
# not already a store URL (the trial serves trix outside the mirror).
sub violations {
  my ($class, $config, $artifactUrlBase) = @_;

  my @extra = index($artifactUrlBase, $STORE_PREFIX) == 0 ? () : ($artifactUrlBase);
  return $VALIDATE->validate($config, {locationPrefixes => \@extra});
}

# Track count by type / adapter / display, for the report.
sub shapeCounts {
  my ($class, $tracks) = @_;
  my %counts;
  foreach my $t (@$tracks) {
    my $display = ref($t->{displays}) eq 'ARRAY' && @{$t->{displays}} ? $t->{displays}[0]{type} : '-';
    $counts{join(' / ', $t->{type} // 'null', $t->{adapter}{type} // 'null', $display // 'null')}++;
  }
  return \%counts;
}

# --- One organism's hub ---

# %$opts: project, build, wsDir, gusHome, outDir, artifactUrlBase, jbrowse, plus seams
#   runScript($gusHome, $script, @args) -> stdout, textIndex($opts, $file, $trackId)
sub buildHub {
  my ($class, $organism, $opts) = @_;

  my $runScript = $opts->{runScript} || sub { $GENERATE->runScript(@_) };
  my $abbrev = $organism->{abbrev};
  my $internal = $organism->{internal_abbrev} || $abbrev;

  my (@tracks, %bySource);
  foreach my $source (@TRACK_SOURCES) {
    my $json = $runScript->($opts->{gusHome}, $source->{script}, $source->{args}->($internal, $opts));
    my $document = eval { decode_json($json) };
    die "$abbrev: $source->{script} did not return JSON for $source->{name}\n" unless($document);

    $GENERATE->assertTracksAreObjects($document, "$abbrev/$source->{name}");
    $bySource{$source->{name}} = scalar @{$document->{tracks} || []};
    push @tracks, @{$document->{tracks} || []};
  }

  my ($hub, $indexed) = $class->hubConfig($organism, \@tracks, $opts->{artifactUrlBase});
  die "$abbrev: no $GENE_MODELS_LABEL track to index\n" if($organism->{is_annotated} && !$indexed);

  my $violations = $class->violations($hub, $opts->{artifactUrlBase});
  if(@$violations) {
    my $counts = $VALIDATE->countByRule($violations);
    my @shown = map { "  $_->{rule} $_->{where}: $_->{message}" } @$violations[0 .. ($#$violations < 9 ? $#$violations : 9)];
    die "$abbrev: " . scalar(@$violations) . " contract violation(s) ("
      . join(', ', map { "$_ $counts->{$_}" } sort keys %$counts) . ")\n" . join("\n", @shown) . "\n";
  }

  return {hub => $hub, sources => \%bySource, shapes => $class->shapeCounts($hub->{tracks})};
}

# --- The whole dump ---

sub writeFile {
  my ($class, $path, $content) = @_;
  open(my $fh, '>:raw', $path) or die "Cannot write $path: $!\n";
  print $fh $content;
  close $fh or die "Cannot close $path: $!\n";
  return 1;
}

sub _md5 {
  my ($path) = @_;
  open(my $fh, '<:raw', $path) or die "Cannot read $path: $!\n";
  return Digest::MD5->new->addfile($fh)->hexdigest;
}

sub _defaultTextIndex {
  my ($opts, $file, $trackId) = @_;

  my $tmp = File::Temp->newdir(DIR => $opts->{outDir});
  my $out = `'$opts->{jbrowse}' text-index --quiet --force --attributes Name,ID --file '$file' --fileId '$trackId' --out '$tmp' 2>&1`;
  die "jbrowse text-index for $trackId failed ($?): $out\n" if($?);

  # The CLI names the files for the input, not --fileId, and its _meta.json (a date and
  # the indexer's local path) is read by nothing on v5.
  my ($base) = $file =~ m{([^/]+)$};
  my @to = __PACKAGE__->trixFiles($trackId);
  my @from = ("trix/$base.ix", "trix/$base.ixx");
  foreach my $i (0 .. $#from) {
    rename("$tmp/$from[$i]", "$opts->{outDir}/$to[$i]")
      or die "jbrowse text-index wrote no $from[$i] for $trackId: $!\n";
  }
}

# The CLI loads no plugins and the root has no plugins key (the site endpoint adds
# them), so a site plugin's root slot is always an unknown slot to it.
our @SITE_PLUGIN_SLOTS = ('VEuPathDBSite');

sub _isSitePluginSlot {
  my ($problem) = @_;
  return grep { $problem->{level} eq 'error' && $problem->{where} eq "configuration.$_"
                && index($problem->{message}, qq{unknown slot "$_"}) == 0 } @SITE_PLUGIN_SLOTS;
}

# A warning fails the dump too: an adapter type v5 does not register is only a warning
# there, and it is a track that never loads.
sub judgeJBrowseValidate {
  my ($class, $exit, $out) = @_;
  my $report = eval { decode_json($out) };
  return (1, $out) unless($report);

  my @problems = @{$report->{problems} || []};
  my @expected = grep { _isSitePluginSlot($_) } @problems;
  my @rest = grep { !_isSitePluginSlot($_) } @problems;
  my $errors = $report->{errorCount} - @expected;

  my $summary = "$errors error(s), $report->{warningCount} warning(s)";
  $summary .= "\n" . join("\n", map { "  $_->{level} $_->{where}: $_->{message}" } @rest) if(@rest);
  $summary .= "\n" . join("\n", map { "  expected $_->{where}: site plugin slot, unknown to the CLI" } @expected)
    if(@expected);
  my $failed = $errors || $report->{warningCount} || ($exit && !@expected);
  return ($failed ? 1 : 0, $summary);
}

sub _defaultJBrowseValidate {
  my ($opts, $path) = @_;
  my $out = `'$opts->{jbrowse}' validate --json '$path' 2>/dev/null`;
  return __PACKAGE__->judgeJBrowseValidate($? >> 8, $out);
}

# No narrowing means every root organism: the root's template names a hub for each.
sub hubAbbrevsFor {
  my ($class, $organisms, $requested) = @_;
  return [@$requested] if($requested && @$requested);
  return [map { $_->{abbrev} } @$organisms];
}

# $organisms: every organism of the project (root + organisms.json).
# $requested: --organism abbrevs narrowing the hubs; empty means all of $organisms.
# Optional seams: clock() -> seconds, progress($abbrev, $seconds, $done, $total).
sub dump {
  my ($class, $organisms, $requested, $opts) = @_;

  my $outDir = $opts->{outDir};
  die "--out-dir $outDir is not empty; the dump writes a whole set, never into an old one\n"
    if(-d $outDir && glob("$outDir/*"));
  make_path("$outDir/trix");

  my %byAbbrev = map { $_->{abbrev} => $_ } @$organisms;
  my $hubAbbrevs = $class->hubAbbrevsFor($organisms, $requested);
  my @unknown = grep { !$byAbbrev{$_} } @$hubAbbrevs;
  die "not organisms of $opts->{project}: @unknown\n" if(@unknown);

  my $fileExists = $opts->{fileExists} || sub { -e $_[0] };
  my $textIndex  = $opts->{textIndex}  || \&_defaultTextIndex;
  my $jbValidate = $opts->{jbrowseValidate} || \&_defaultJBrowseValidate;
  my $clock      = $opts->{clock}    || \&Time::HiRes::time;
  my $progress   = $opts->{progress} || sub {};
  my $build = "$opts->{wsDir}/$opts->{project}/build-$opts->{build}";

  foreach my $organism (@$organisms) {
    my @paths = ($class->genomeFastaPath($organism));
    push @paths, $class->proteinFastaPath($organism) if($organism->{is_annotated});
    foreach my $path (@paths) {
      die "$organism->{abbrev}: $build/$path(.fai) not in the mirror\n"
        unless($fileExists->("$build/$path") && $fileExists->("$build/$path.fai"));
    }
  }

  my (%written, %jbrowseValidate);
  # Each file is validated as soon as it is written, so a full run fails at the
  # organism that broke rather than after every other hub is built.
  my $validate = sub {
    my ($file) = @_;
    my ($status, $out) = $jbValidate->($opts, "$outDir/$file");
    $jbrowseValidate{$file} = {status => $status, output => $out};
    die "jbrowse validate $file exited $status:\n$out" if($status);
  };

  my $root = $class->rootConfig($organisms, $opts->{artifactUrlBase});
  $class->writeFile("$outDir/config.json", $class->encodeJson($root));
  $written{'config.json'} = 1;
  $validate->('config.json');

  $class->writeFile("$outDir/organisms.json", $class->encodeJson($class->organismList($organisms)));
  $written{'organisms.json'} = 1;

  my %summaries;
  my @ordered = sort @$hubAbbrevs;
  foreach my $abbrev (@ordered) {
    my $started = $clock->();
    my $organism = $byAbbrev{$abbrev};
    my $built = $class->buildHub($organism, $opts);
    my $file = $class->hubFile($abbrev);
    $class->writeFile("$outDir/$file", $class->encodeJson($built->{hub}));
    $written{$file} = 1;
    $validate->($file);

    if($organism->{is_annotated}) {
      my $trackId = $class->geneModelsTrackId($organism);
      $textIndex->($opts, "$build/" . $class->geneGffPath($organism), $trackId);
      $written{$_} = 1 foreach($class->trixFiles($trackId));
    }
    $built->{seconds} = $clock->() - $started;
    $summaries{$abbrev} = $built;
    $progress->($abbrev, $built->{seconds}, scalar(keys %summaries), scalar @ordered);
  }

  my @manifest = map { {file => $_, bytes => -s "$outDir/$_", md5 => _md5("$outDir/$_"),
                        mirror => $class->mirrorPath($opts, $_)} } sort keys %written;
  $class->writeFile("$outDir/manifest.tsv",
                    join('', map { "$_->{file}\t$_->{bytes}\t$_->{md5}\t$_->{mirror}\n" } @manifest));

  my @noHub = sort grep { !$summaries{$_} } keys %byAbbrev;
  return {root_assemblies => scalar @{$root->{assemblies}}, organisms => scalar @$organisms,
          hub_url_template => $root->{configuration}{VEuPathDBSite}{hubUrlTemplate},
          hubs => \%summaries, no_hub => \@noHub, manifest => \@manifest,
          jbrowse_validate => \%jbrowseValidate};
}

1;
