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
  my $root = $H->rootConfig(\@ORGANISMS);
  is_deeply([map { $_->{name} } @{$root->{assemblies}}],
            [qw(pberANKA pberANKA_protein pfal3D7 pfal3D7_protein pfalNoAnno)],
            'root: every genome and protein assembly, sorted');
  ok(!exists $root->{tracks}, 'root: no tracks');

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

  my ($again) = opts();
  $H->dump(\@ORGANISMS, ['pfal3D7'], $again);
  foreach my $file (qw(config.json organisms.json pfal3D7.hub.json)) {
    is(slurp("$again->{outDir}/$file"), slurp("$out/$file"), "two runs give identical $file");
  }

  eval { $H->dump(\@ORGANISMS, ['pfal3D7'], $opts) };
  like($@, qr/is not empty/, 'refuses to write into a directory that already holds a dump');
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

done_testing();
