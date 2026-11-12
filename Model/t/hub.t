use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use JSON;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::JBrowseConfigRelease::Hub;

my $H = 'ApiCommonModel::Model::JBrowseConfigRelease::Hub';
my $S = '/a/service/jbrowse/store?data=';

my @ORGANISMS = (
  {abbrev => 'pfal3D7', internal_abbrev => 'pfal3D7', name => 'Plasmodium falciparum 3D7',
   name_for_filenames => 'Pfalciparum3D7', is_annotated => 1, genus => 'Plasmodium',
   species => 'Plasmodium falciparum', strain => '3D7'},
  {abbrev => 'pberANKA', internal_abbrev => 'pberANKA_int', name => 'Plasmodium berghei ANKA',
   name_for_filenames => 'PbergheiANKA', is_annotated => 1, genus => 'Plasmodium',
   species => 'Plasmodium berghei', strain => 'ANKA'},
  {abbrev => 'pfalNoAnno', internal_abbrev => 'pfalNoAnno', name => 'Plasmodium falciparum X',
   name_for_filenames => 'PfalciparumX', is_annotated => 0, genus => 'Plasmodium',
   species => 'Plasmodium falciparum', strain => 'X'},
);

sub loc { {uri => $S . $_[0], locationType => 'UriLocation'} }

sub feature {
  my ($id, $assembly, $path) = @_;
  return {type => 'FeatureTrack', trackId => $id, name => $id, assemblyNames => [$assembly],
          adapter => {type => 'Gff3TabixAdapter', gffGzLocation => loc($path),
                      index => {location => loc("$path.tbi")}},
          displays => [{type => 'LinearBasicDisplay', displayId => "$id-LinearBasicDisplay"}]};
}

# What each producer prints for pfal3D7, in the order the producers emit it.
my %PRODUCED = (
  jbrowseRnaAndChipSeqTracks => {tracks => [
    {type => 'QuantitativeTrack', trackId => 'pfal3D7_ds_cov', name => 'cov', assemblyNames => ['pfal3D7'],
     adapter => {type => 'BigWigAdapter', bigWigLocation => loc('Pfalciparum3D7/a.bw')},
     displays => [{type => 'LinearWiggleDisplay', displayId => 'pfal3D7_ds_cov-LinearWiggleDisplay'}]}]},
  jbrowseRNASeqJunctionTracks => {tracks => []},
  jbrowseOrganismSpecificTracks => {tracks => [
    feature('pfal3D7_GeneModels', 'pfal3D7', 'Pfalciparum3D7/genomeAndProteome/gff/annotated_transcripts.gff.gz'),
    feature('pfal3D7_Centromere', 'pfal3D7', 'Pfalciparum3D7/genomeBrowser/gff/centromere.gff.gz')]},
  jbrowseDNASeqTracks => {tracks => []},
  jbrowseOrganismSpecificPbrowseTracks => {tracks => [
    feature('pfal3D7_protein_InterproDomains', 'pfal3D7_protein', 'Pfalciparum3D7/genomeAndProteome/gff/iprscan_out.gff.gz')]},
);

# ChIP-seq produces nothing unless a test asks it to repeat RNA-seq's tracks.
sub opts {
  my (%override) = @_;
  my @calls;
  my $chipRepeatsRna = delete $override{chipRepeatsRna};
  my %opts = (
    project => 'PlasmoDB', build => 71, wsDir => '/ws', gusHome => '/gus',
    outDir => tempdir(CLEANUP => 1) . '/out', jbrowse => '/bin/jbrowse',
    artifactUrlBase => '/plasmo.x/jbrowse2-v5dump/',
    runScript => sub { my ($gus, $script, @args) = @_; push @calls, [$script, @args];
                       return encode_json({tracks => []})
                         if($script eq 'jbrowseRnaAndChipSeqTracks' && $args[4] eq 'ChIPSeq' && !$chipRepeatsRna);
                       return encode_json($PRODUCED{$script} || {tracks => []}) },
    fileExists => sub { 1 },
    readFile => sub { '' },
    textIndex => sub { my ($o, $file, $trackId) = @_;
                       foreach my $f ($H->trixFiles($trackId)) {
                         open(my $fh, '>', "$o->{outDir}/$f") or die $!; print $fh "index of $file\n"; close $fh } },
    jbrowseValidate => sub { (0, 'looks good') },
    %override,
  );
  return (\%opts, \@calls);
}

sub slurp { open(my $fh, '<', $_[0]) or die "$_[0]: $!"; local $/; return scalar <$fh> }

# --- assemblies ---
{
  my $genome = $H->genomeAssembly($ORGANISMS[0]);
  is($genome->{name}, 'pfal3D7', 'genome assembly is the public abbrev');
  is($genome->{sequence}{adapter}{fastaLocation}{uri}, "${S}Pfalciparum3D7/genomeAndProteome/fasta/genome.fasta",
     'from the genome FASTA in the store');
  is($genome->{sequence}{adapter}{faiLocation}{uri}, "${S}Pfalciparum3D7/genomeAndProteome/fasta/genome.fasta.fai",
     'with its .fai');

  my $protein = $H->proteinAssembly($ORGANISMS[0]);
  is($protein->{name}, 'pfal3D7_protein', 'protein assembly is <abbrev>_protein');
  is($protein->{sequence}{sequenceType}, 'pep', 'its reference track reads residues');
  is($protein->{sequence}{adapter}{type}, 'IndexedFastaAdapter', 'from an indexed FASTA');
  like($protein->{sequence}{adapter}{fastaLocation}{uri}, qr{AnnotatedProteins\.fasta$}, 'the proteome');

  is(scalar($H->assembliesFor($ORGANISMS[2])), 1, 'an unannotated organism has no protein assembly');
}

# --- root config and organism list ---
{
  my $root = $H->rootConfig(\@ORGANISMS, '/plasmo.x/jbrowse2-v5dump/');
  is_deeply([map { $_->{name} } @{$root->{assemblies}}],
            [qw(pberANKA pberANKA_protein pfal3D7 pfal3D7_protein pfalNoAnno)],
            'root: every genome and protein assembly, sorted');
  ok(!exists $root->{tracks}, 'root: no tracks');
  ok(!exists $root->{plugins}, 'root: no plugins (the site endpoint adds them)');
  is_deeply([sort keys %$root], [qw(assemblies configuration)], 'root: assemblies and configuration only');

  is_deeply($root->{configuration},
            {VEuPathDBSite => {hubUrlTemplate => '/plasmo.x/jbrowse2-v5dump/{abbrev}.hub.json'}},
            'root: the hub URL template is the explicit artifact base plus {abbrev}.hub.json');

  my $default = $H->rootConfig(\@ORGANISMS, $H->defaultArtifactUrlBase())
    ->{configuration}{VEuPathDBSite}{hubUrlTemplate};
  is($default, "${S}jbrowse2/{abbrev}.hub.json",
     'root: with the default base the template is the hubs\' store URL');
  like($default, qr/\{abbrev\}/, 'root: {abbrev} reaches the plugin unescaped');
  unlike($default, qr/%7B|%7D/i, 'root: the placeholder is never percent-encoded');

  eval { $H->rootConfig(\@ORGANISMS) };
  like($@, qr/needs the artifact URL base/, 'root: refuses to build a template without a base');

  is_deeply($H->organismList([reverse @ORGANISMS])->[1],
            {abbrev => 'pfal3D7', displayName => 'Plasmodium falciparum 3D7', genus => 'Plasmodium',
             species => 'Plasmodium falciparum', strain => '3D7'},
            'organisms.json rows: abbrev, display name, genus, species, strain; sorted by abbrev');
}

# --- the hub ---
{
  my ($opts, $calls) = opts();
  my $built = $H->buildHub($ORGANISMS[0], $opts);
  my $hub = $built->{hub};

  is_deeply([map { $_->{name} } @{$hub->{assemblies}}], [qw(pfal3D7 pfal3D7_protein)],
            'hub declares the genome and protein assemblies');
  is_deeply([map { $_->{trackId} } @{$hub->{tracks}}],
            [qw(pfal3D7_Centromere pfal3D7_GeneModels pfal3D7_ds_cov pfal3D7_protein_InterproDomains)],
            'every producer\'s tracks, sorted by trackId')
    or diag explain [map { $_->{trackId} } @{$hub->{tracks}}];
  is(scalar(grep { $_->[0] eq 'jbrowseRnaAndChipSeqTracks' } @$calls), 2, 'RNA-seq and ChIP-seq both asked');
  ok(!grep({ $_->[-1] ne 'jbrowse2' } @$calls), 'every producer runs as jbrowse2');
  is($calls->[0][1], 'pfal3D7', 'producers get the internal abbrev');
}

{
  my ($opts) = opts(chipRepeatsRna => 1);
  eval { $H->buildHub($ORGANISMS[0], $opts) };
  like($@, qr/contract violation.*track-id-duplicate/s, 'a contract violation fails the hub');
}

{
  my ($opts) = opts();
  my $hub =$H->buildHub($ORGANISMS[0], $opts)->{hub};
  my ($genes) = grep { $_->{trackId} eq 'pfal3D7_GeneModels' } @{$hub->{tracks}};
  is_deeply($genes->{textSearching}{textSearchAdapter},
            {type => 'TrixTextSearchAdapter', assemblyNames => ['pfal3D7'],
             ixFilePath => {uri => '/plasmo.x/jbrowse2-v5dump/trix/pfal3D7_GeneModels.ix', locationType => 'UriLocation'},
             ixxFilePath => {uri => '/plasmo.x/jbrowse2-v5dump/trix/pfal3D7_GeneModels.ixx', locationType => 'UriLocation'}},
            'the gene-model track carries a track-level trix index on the genome assembly');
  is(scalar(grep { $_->{textSearching} } @{$hub->{tracks}}), 1, 'and only that track');

  my $storeDefault = $H->defaultArtifactUrlBase();
  is($storeDefault, "${S}jbrowse2/", 'by default a new artifact is addressed in its mirror home');

  my ($elsewhere) = opts(artifactUrlBase => '/elsewhere/');
  eval { $H->buildHub($ORGANISMS[0], $elsewhere) };
  is($@, '', 'the artifact base the caller names is accepted by the validator');
}

{
  local $PRODUCED{jbrowseOrganismSpecificTracks} = {tracks => [
    feature('pfal3D7_Centromere', 'pfal3D7', 'Pfalciparum3D7/genomeBrowser/gff/centromere.gff.gz')]};
  my ($opts) = opts();
  eval { $H->buildHub($ORGANISMS[0], $opts) };
  like($@, qr/no GeneModels track to index/, 'an annotated organism with no gene-model track fails');
}

{
  local $PRODUCED{jbrowseDNASeqTracks} = {tracks => [1]};
  my ($opts) = opts();
  eval { $H->buildHub($ORGANISMS[0], $opts) };
  like($@, qr/not JSON objects/, 'a producer emitting a non-object fails');
}

# Every organism's producers emit just its gene-model track; enough for a whole-project dump.
my %PUBLIC = map { ($_->{internal_abbrev} => $_->{abbrev}) } @ORGANISMS;
sub geneModelsOnly {
  my ($gus, $script, $internal) = @_;
  my $abbrev = $PUBLIC{$internal};
  return encode_json({tracks => []}) unless($script eq 'jbrowseOrganismSpecificTracks');
  return encode_json({tracks => [feature("${abbrev}_GeneModels", $abbrev, "x/$abbrev.gff.gz")]});
}

# Each organism's producers emit gene models and a centromere on its genome and, from the
# protein producer, an InterPro track on <abbrev>_protein, as they do for an unannotated one.
sub genomeAndProteinTracks {
  my ($gus, $script, $internal) = @_;
  my $abbrev = $PUBLIC{$internal};
  return encode_json({tracks => [feature("${abbrev}_Centromere", $abbrev, "x/$abbrev.centromere.gff.gz"),
                                 feature("${abbrev}_GeneModels", $abbrev, "x/$abbrev.gff.gz")]})
    if($script eq 'jbrowseOrganismSpecificTracks');
  return encode_json({tracks => [feature("${abbrev}_protein_InterproDomains", "${abbrev}_protein", "x/$abbrev.ipr.gff.gz")]})
    if($script eq 'jbrowseOrganismSpecificPbrowseTracks');
  return encode_json({tracks => []});
}

# --- the protein producer needs a protein assembly ---
{
  my @calls;
  my $runScript = sub { push @calls, $_[1]; genomeAndProteinTracks(@_) };
  my ($opts) = opts(runScript => $runScript);

  my $annotated = $H->buildHub($ORGANISMS[1], $opts);
  ok((grep { $_ eq 'jbrowseOrganismSpecificPbrowseTracks' } @calls), 'annotated: the protein producer runs');
  is_deeply($annotated->{skipped}, [], 'annotated: nothing skipped');
  ok((grep { $_->{trackId} eq 'pberANKA_protein_InterproDomains' } @{$annotated->{hub}{tracks}}),
     'annotated: its protein tracks are in the hub');

  @calls = ();
  my $unannotated = $H->buildHub($ORGANISMS[2], $opts);
  ok(!(grep { $_ eq 'jbrowseOrganismSpecificPbrowseTracks' } @calls), 'unannotated: the protein producer does not run');
  is_deeply($unannotated->{skipped}, ['organismSpecificPbrowse'], 'unannotated: the skip is reported');
  is_deeply([map { $_->{trackId} } @{$unannotated->{hub}{tracks}}], [qw(pfalNoAnno_Centromere pfalNoAnno_GeneModels)],
            'unannotated: genome tracks only');
  is_deeply($H->violations($unannotated->{hub}, $opts->{artifactUrlBase}), [], 'unannotated: the hub validates');

  my $withProteins = {%{$unannotated->{hub}}, tracks => [@{$unannotated->{hub}{tracks}},
                      feature('pfalNoAnno_protein_InterproDomains', 'pfalNoAnno_protein', 'x/p.gff.gz')]};
  ok((grep { $_->{rule} eq 'assembly-names' } @{$H->violations($withProteins, $opts->{artifactUrlBase})}),
     'unannotated: a protein track would name an assembly the hub cannot declare');

  my ($dumpOpts) = opts(runScript => \&genomeAndProteinTracks);
  my $result = $H->dump(\@ORGANISMS, [], $dumpOpts);
  is_deeply($result->{protein_producer_skipped}, ['pfalNoAnno'], 'dump: reports the organisms the protein producer skipped');
}

# --- the dump ---
{
  my ($opts) = opts();
  my $result = $H->dump(\@ORGANISMS, ['pfal3D7'], $opts);
  my $out = $opts->{outDir};

  is($result->{root_assemblies}, 5, 'root assembly count');
  is_deeply([map { $_->{file} } @{$result->{manifest}}],
            [qw(config.json organisms.json pfal3D7.hub.json trix/pfal3D7_GeneModels.ix trix/pfal3D7_GeneModels.ixx)],
            'writes root, organism list, one hub and its trix index');
  is($result->{manifest}[2]{mirror}, '/ws/PlasmoDB/build-71/jbrowse2/pfal3D7.hub.json',
     'every file says where it lives in the webServices mirror');
  like(slurp("$out/manifest.tsv"), qr{^config\.json\t\d+\t[0-9a-f]{32}\t/ws/PlasmoDB/build-71/jbrowse2/config\.json$}m,
       'manifest.tsv: file, bytes, md5, mirror path');
  is_deeply([sort keys %{$result->{jbrowse_validate}}], [qw(config.json pfal3D7.hub.json)],
            'jbrowse validate runs on the root and on each hub');
  is_deeply($result->{no_hub}, [qw(pberANKA pfalNoAnno)], 'reports the root organisms that got no hub');
  is($result->{hub_url_template}, '/plasmo.x/jbrowse2-v5dump/{abbrev}.hub.json',
     'reports the template, built from the dump\'s artifact base');
  is(decode_json(slurp("$out/config.json"))->{configuration}{VEuPathDBSite}{hubUrlTemplate},
     '/plasmo.x/jbrowse2-v5dump/{abbrev}.hub.json', 'the written root carries the template');
  is($H->hubUrlTemplate($opts->{artifactUrlBase}) =~ s/\{abbrev\}/pfal3D7/r,
     $opts->{artifactUrlBase} . $result->{manifest}[2]{file},
     'the template resolves to the hub file the dump wrote');

  my ($again) = opts();
  $H->dump(\@ORGANISMS, ['pfal3D7'], $again);
  foreach my $file (qw(config.json organisms.json pfal3D7.hub.json)) {
    is(slurp("$again->{outDir}/$file"), slurp("$out/$file"), "two runs give identical $file");
  }

  eval { $H->dump(\@ORGANISMS, ['pfal3D7'], $opts) };
  like($@, qr/is not empty/, 'refuses to write into a directory that already holds a dump');
}

{
  my $tick = 0;
  my @progress;
  my ($opts) = opts(runScript => \&geneModelsOnly,
                    clock => sub { $tick += 2 },
                    progress => sub { push @progress, [@_] });
  my $result = $H->dump(\@ORGANISMS, [], $opts);
  is_deeply([sort keys %{$result->{hubs}}], [qw(pberANKA pfal3D7 pfalNoAnno)],
            'no --organism: a hub for every root organism');
  is_deeply($result->{no_hub}, [], 'no --organism: no root organism is left without a hub');
  is_deeply([map { $_->{file} } @{$result->{manifest}}],
            [qw(config.json organisms.json pberANKA.hub.json pfal3D7.hub.json pfalNoAnno.hub.json
                trix/pberANKA_GeneModels.ix trix/pberANKA_GeneModels.ixx
                trix/pfal3D7_GeneModels.ix trix/pfal3D7_GeneModels.ixx)],
            'no --organism: trix only for the annotated organisms');
  is_deeply([sort keys %{$result->{jbrowse_validate}}],
            [qw(config.json pberANKA.hub.json pfal3D7.hub.json pfalNoAnno.hub.json)],
            'every hub is validated');
  is($result->{hubs}{pfal3D7}{seconds}, 2, 'each hub reports its own time');
  is_deeply([map { [$_->[0], @$_[2, 3]] } @progress],
            [[pberANKA => 1, 3], [pfal3D7 => 2, 3], [pfalNoAnno => 3, 3]],
            'progress is reported per organism, in order');
}

{
  my ($opts) = opts();
  my $result = $H->dump(\@ORGANISMS, ['pfal3D7'], $opts);
  is_deeply([sort keys %{$result->{hubs}}], ['pfal3D7'], '--organism: only the named hubs');
  is_deeply($result->{no_hub}, [qw(pberANKA pfalNoAnno)], '--organism: the rest are reported hubless');
}

{
  my @validated;
  my ($opts) = opts(jbrowseValidate => sub { push @validated, $_[1] =~ s{.*/}{}r;
                                             $_[1] =~ /pfal3D7\.hub/ ? (1, 'broken') : (0, 'ok') },
                    runScript => \&geneModelsOnly);
  eval { $H->dump(\@ORGANISMS, [], $opts) };
  like($@, qr/jbrowse validate pfal3D7\.hub\.json exited 1/, 'a failing hub names its organism');
  is_deeply(\@validated, [qw(config.json pberANKA.hub.json pfal3D7.hub.json)],
            'and stops there, before building the hubs after it');
}

{
  my ($opts) = opts();
  eval { $H->dump(\@ORGANISMS, ['tgonME49'], $opts) };
  like($@, qr/not organisms of PlasmoDB: tgonME49/, 'a hub for an organism outside the project is refused');
}

{
  my ($opts) = opts(fileExists => sub { $_[0] !~ /AnnotatedProteins\.fasta\.fai$/ || $_[0] !~ /Pbergh/ });
  eval { $H->dump(\@ORGANISMS, ['pfal3D7'], $opts) };
  like($@, qr{pberANKA: .*AnnotatedProteins\.fasta\(\.fai\) not in the mirror}, 'a declared assembly must exist in the mirror');
}

{
  my ($opts) = opts(jbrowseValidate => sub { (1, '0 error(s), 1 warning(s)') });
  eval { $H->dump(\@ORGANISMS, ['pfal3D7'], $opts) };
  like($@, qr/jbrowse validate config\.json exited 1/, 'jbrowse validate failing fails the dump');
}

# --- judging `jbrowse validate --json` ---
{
  my $problem = sub { my ($level, $where, $message) = @_; {level => $level, where => $where, message => $message} };
  my $report = sub { my @p = @_;
    encode_json({problems => \@p, errorCount => scalar(grep { $_->{level} eq 'error' } @p),
                 warningCount => scalar(grep { $_->{level} eq 'warning' } @p)}) };
  my $siteSlot = $problem->('error', 'configuration.VEuPathDBSite',
                            'unknown slot "VEuPathDBSite" — JBrowse ignores keys it does not declare');

  my ($status, $summary) = $H->judgeJBrowseValidate(1, $report->($siteSlot));
  is($status, 0, 'validate: the site plugin\'s root slot alone passes');
  like($summary, qr/^0 error\(s\), 0 warning\(s\)\n  expected configuration\.VEuPathDBSite/,
       'validate: and is reported as expected, not hidden');

  ($status) = $H->judgeJBrowseValidate(1, $report->($siteSlot,
    $problem->('error', 'configuration.Other', 'unknown slot "Other"')));
  is($status, 1, 'validate: any other unknown root slot still fails');

  ($status) = $H->judgeJBrowseValidate(0, $report->($siteSlot,
    $problem->('warning', 'tracks[0].adapter', 'type not registered')));
  is($status, 1, 'validate: a warning beside the site slot still fails');

  ($status) = $H->judgeJBrowseValidate(1, $report->(
    $problem->('error', 'tracks[0].configuration.VEuPathDBSite', 'unknown slot "VEuPathDBSite"')));
  is($status, 1, 'validate: the exemption is for the root slot only');

  ($status) = $H->judgeJBrowseValidate(1, 'not json');
  is($status, 1, 'validate: unreadable output fails');

  ($status) = $H->judgeJBrowseValidate(0, $report->());
  is($status, 0, 'validate: a clean report passes');
}

# --- the static tracks.conf, one more source after the producers ---
my $CONF = <<"CONF";
[tracks.gcContent]
storeClass=JBrowse/Store/SeqFeature/REST
key=GC Content

[tracks.AdamsPiggyBac]
storeClass=JBrowse/Store/SeqFeature/GFF3Tabix
urlTemplate=${S}\${nameForFileNames}/prealigned/gff/piggyBac.gff.gz
key=piggyBac insertion sites
category=Sequence Analysis

[tracks.HP1]
storeClass=JBrowse/Store/SeqFeature/BigWig
urlTemplate=/a/service/jbrowse/auxiliary?data=PlasmoDB/HP1/ring.bw
key=HP1
category=Epigenomics
CONF

{
  my @read;
  my ($opts) = opts(runScript => \&geneModelsOnly,
                    readFile => sub { push @read, $_[0]; $CONF });
  my $built = $H->buildHub($ORGANISMS[1], $opts);

  is_deeply(\@read, ['/gus/lib/jbrowse/auto_generated/pberANKA_int/tracks.conf'],
            'tracks.conf is read from auto_generated/<INTERNAL>/ under GUS_HOME');
  is($built->{sources}{tracksConf}, 2, 'its tracks are counted as their own source');
  ok((grep { $_->{trackId} eq 'pberANKA_AdamsPiggyBac' } @{$built->{hub}{tracks}}), 'and join the hub');
  is($built->{tracksConf}{stanzas}, 3, 'the report counts stanzas read');
  is_deeply($built->{tracksConf}{rest}, ['gcContent'], 'and the REST stanzas skipped');
  is_deeply($H->violations($built->{hub}, $opts->{artifactUrlBase}), [], 'a hub with static tracks validates');

  my %existing = map { $_ => 1 } '/ws/PlasmoDB/build-71/PbergheiANKA/prealigned/gff/piggyBac.gff.gz';
  my ($dumpOpts) = opts(runScript => \&geneModelsOnly, readFile => sub { $CONF },
                        fileExists => sub { $_[0] !~ m{/(prealigned|PlasmoDB/HP1)/} || $existing{$_[0]} });
  my $result = $H->dump(\@ORGANISMS, ['pberANKA'], $dumpOpts);
  is_deeply([sort map { $_->{file} } @{$result->{tracks_conf_missing}}],
            ['/ws/PlasmoDB/HP1/ring.bw', '/ws/PlasmoDB/build-71/PbergheiANKA/prealigned/gff/piggyBac.gff.gz.tbi'],
            'dump: a store or auxiliary file absent from the mirror is reported, not fatal');
  is_deeply($result->{tracks_conf_not_mirror}, [], 'dump: every location is a store or auxiliary URL');
}

{
  is($H->mirrorFileForUri("${S}a%20b/c.bw", {wsDir => '/x/webServices', project => 'P', build => 9}),
     '/x/webServices/P/build-9/a b/c.bw', 'mirror path: store data is under <ws>/<project>/build-<n>/, unescaped');
  is($H->mirrorFileForUri('/a/service/jbrowse/auxiliary?data=T/a.bw', {wsDir => '/x/webServices'}),
     '/x/auxiliary/T/a.bw', 'mirror path: auxiliary swaps webServices for auxiliary, as JBrowseService does');
  is($H->mirrorFileForUri('/plasmo.x/jbrowse2-demo/a.bw', {wsDir => '/x/webServices'}), undef,
     'mirror path: anything else is not a mirror location');

  my ($opts) = opts(runScript => \&geneModelsOnly, readFile => sub { "[tracks.a]\nkey=A\nstray\n" });
  eval { $H->buildHub($ORGANISMS[0], $opts) };
  like($@, qr{^/gus/lib/jbrowse/auto_generated/pfal3D7/tracks\.conf:3: not a section}, 'a stanza that does not parse fails the hub');
}

done_testing();
