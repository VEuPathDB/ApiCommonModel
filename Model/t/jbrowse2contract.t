use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::DatasetConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::BigWigStore;
use ApiCommonModel::Model::JBrowseTrackConfig::GFFStore;
use ApiCommonModel::Model::JBrowseTrackConfig::BedStore;
use ApiCommonModel::Model::JBrowseTrackConfig::VCFStore;
use ApiCommonModel::Model::JBrowseTrackConfig::BamStore;
use ApiCommonModel::Model::JBrowseTrackConfig::FastaStore;
use ApiCommonModel::Model::JBrowseTrackConfig::AuxiliaryGFFStore;
use ApiCommonModel::Model::JBrowseConfigRelease::Validate;

my $NS = 'ApiCommonModel::Model::JBrowseTrackConfig';

# The public abbrev comes from GUS_HOME's per-organism props; point it at a fixture.
my $gusHome = tempdir(CLEANUP => 1);
my $realGusHome = $ENV{GUS_HOME};
foreach([intPfal => 'pfal3D7'], [intAaqu => 'aaquAaquGF1']) {
  my ($internal, $public) = @$_;
  make_path("$gusHome/lib/jbrowse/auto_generated/$internal");
  open(my $fh, '>', "$gusHome/lib/jbrowse/auto_generated/$internal/datasetAndPresenterProps.conf") or die $!;
  print $fh "organism::organismAbbrev=$internal\norganism::publicOrganismAbbrev=$public\n";
  close $fh;
}
local $ENV{GUS_HOME} = $gusHome;

sub store {
  my ($class, $appType, $path) = @_;
  return "${NS}::$class"->new({application_type => $appType, project_name => 'PlasmoDB',
                               build_number => 71, relative_path_to_file => $path});
}

# --- Store URLs: jbrowse2 is site-relative, jbrowse is byte-for-byte what it was ---
{
  my $path = 'Pfalciparum3D7/bulkrnaseq/bigwig/ds 1/a b.bw';
  is(store('BigWigStore', 'jbrowse', $path)->getUrlTemplate(),
     '/a/service/jbrowse/store?data=Pfalciparum3D7%2Fbulkrnaseq%2Fbigwig%2Fds%201%2Fa%20b.bw',
     'jbrowse store URL is unchanged (fully escaped)');
  is(store('BigWigStore', 'jbrowse2', $path)->getUrlTemplate(),
     '/a/service/jbrowse/store?data=Pfalciparum3D7/bulkrnaseq/bigwig/ds%201/a%20b.bw',
     'jbrowse2 store URL is site-relative, no <project>/build-<n>/ prefix, slashes kept');
  is(store('AuxiliaryGFFStore', 'jbrowse', 'x/c.gff.gz')->getUrlTemplate(),
     '/a/service/jbrowse/auxiliary?data=x%2Fc.gff.gz', 'jbrowse auxiliary URL is unchanged');
  is(store('AuxiliaryGFFStore', 'jbrowse2', 'x/c.gff.gz')->getUrlTemplate(),
     '/a/service/jbrowse/auxiliary?data=x/c.gff.gz', 'jbrowse2 auxiliary URL is site-relative');
}

# --- Store locations carry their indexes ---
{
  my $S = '/a/service/jbrowse/store?data=';
  my $u = sub { {uri => $S . $_[0], locationType => 'UriLocation'} };

  is_deeply(store('BigWigStore', 'jbrowse2', 'P/a.bw')->getJBrowse2Locations(),
            {bigWigLocation => $u->('P/a.bw')}, 'bigwig: data only');
  is_deeply(store('GFFStore', 'jbrowse2', 'P/a.gff.gz')->getJBrowse2Locations(),
            {gffGzLocation => $u->('P/a.gff.gz'), index => {location => $u->('P/a.gff.gz.tbi')}},
            'gff tabix: data + .tbi index');
  is_deeply(store('BamStore', 'jbrowse2', 'P/a.bam')->getJBrowse2Locations(),
            {bamLocation => $u->('P/a.bam'), index => {location => $u->('P/a.bam.bai')}},
            'bam: data + .bai index');

  my $vcf = "${NS}::VCFStore"->new({application_type => 'jbrowse2', project_name => 'PlasmoDB',
                                     build_number => 71, relative_path_to_file => 'P/v.vcf.gz'});
  is_deeply($vcf->getJBrowse2Locations(),
            {vcfGzLocation => $u->('P/v.vcf.gz'), index => {location => $u->('P/v.vcf.gz.tbi')}},
            'vcf tabix: data + .tbi index');

  my $fasta = store('FastaStore', 'jbrowse2', 'P/g.fasta');
  is($fasta->getStoreType(), 'IndexedFastaAdapter', 'jbrowse2 fasta adapter has its v5 name');
  is(store('FastaStore', 'jbrowse', 'P/g.fasta')->getStoreType(), 'JBrowse/Store/SeqFeature/IndexedFasta',
     'jbrowse fasta store type is unchanged');

  is_deeply(store('BigWigStore', 'jbrowse2', undef)->getJBrowse2Locations(), {},
            'no file, no locations');
}

# --- the contract on a track ---
sub track {
  my (%args) = @_;
  my $datasetConfig = "${NS}::DatasetConfig"->new({
    dataset_name => $args{dataset}, organism_abbrev => $args{organism},
    category => 'Transcriptomics', subcategory => 'RNA-Seq', study_display_name => 'Study'});
  my $track = "${NS}::TrackConfig"->new({
    application_type => $args{app} || 'jbrowse2', dataset_config => $datasetConfig,
    label => $args{label}, id => 'Display name', store => $args{store}});
  $track->setTrackType('QuantitativeTrack');
  $track->setDisplayType('LinearWiggleDisplay');
  return $track;
}

{
  my $bw = store('BigWigStore', 'jbrowse2', 'Pfalciparum3D7/bulkrnaseq/bigwig/pfal3D7_Duffy_rnaSeq_RSRC/a.bw');
  my $obj = track(dataset => 'pfal3D7_Duffy_rnaSeq_RSRC', organism => 'intPfal',
                  label => 'pfal3D7_Duffy_rnaSeq_RSRC - Unique And Non-Unique', store => $bw)
              ->getConfigurationObject();

  is($obj->{trackId}, 'pfal3D7_Duffy_rnaSeq_RSRC_Unique_And_Non-Unique',
     'label with the dataset in it: separators become _, abbrev not prefixed twice');
  is_deeply($obj->{assemblyNames}, ['pfal3D7'], 'assemblyNames is the PUBLIC abbrev');
  is($obj->{displays}[0]{displayId}, "$obj->{trackId}-LinearWiggleDisplay", 'displayId from trackId');
  is($obj->{adapter}{bigWigLocation}{uri},
     '/a/service/jbrowse/store?data=Pfalciparum3D7/bulkrnaseq/bigwig/pfal3D7_Duffy_rnaSeq_RSRC/a.bw',
     'adapter carries the store location');

  is_deeply(track(dataset => 'pfal3D7_Duffy_rnaSeq_RSRC', organism => 'intPfal',
                  label => 'pfal3D7_Duffy_rnaSeq_RSRC - Unique And Non-Unique', store => $bw)
              ->getConfigurationObject(),
            $obj, 'deterministic: the same inputs give the same object');

  is(track(dataset => 'DS_RSRC', organism => 'intPfal', label => 'sample 1 - peaks', store => $bw)
       ->getConfigurationObject()->{trackId},
     'pfal3D7_DS_RSRC_sample_1_peaks', 'a label without the dataset gets <abbrev>_<dataset>_ in front');
  is(track(dataset => undef, organism => 'intPfal', label => 'Centromere', store => $bw)
       ->getConfigurationObject()->{trackId},
     'pfal3D7_Centromere', 'no dataset: <abbrev>_<name>');
  is(track(dataset => 'aaqu_DS', organism => 'intAaqu', label => 'cov', store => $bw)
       ->getConfigurationObject()->{assemblyNames}[0],
     'aaquAaquGF1', 'public abbrev differs from the internal one when the props say so');

  my $orphan = track(dataset => 'DS', organism => undef, label => 'x', store => $bw)->getConfigurationObject();
  is_deeply($orphan->{assemblyNames}, [undef],
            'a producer that names no organism gets [null] -- left for the validator to report');
  ok(scalar(grep { $_->{rule} eq 'assembly-names' }
            @{ApiCommonModel::Model::JBrowseConfigRelease::Validate->validate(
                {assemblies => [{name => 'pfal3D7'}], tracks => [$orphan]})}),
     'and the validator does report it');

  my $conforming = track(dataset => 'pfal3D7_Duffy_rnaSeq_RSRC', organism => 'intPfal',
                         label => 'pfal3D7_Duffy_rnaSeq_RSRC - unique', store => $bw)->getConfigurationObject();
  my $v = ApiCommonModel::Model::JBrowseConfigRelease::Validate->validate({
    assemblies => [{name => 'pfal3D7', sequence => {adapter => {
      type => 'IndexedFastaAdapter',
      fastaLocation => {uri => '/a/service/jbrowse/store?data=g.fa'},
      faiLocation => {uri => '/a/service/jbrowse/store?data=g.fa.fai'}}}}],
    tracks => [$conforming]});
  is_deeply($v, [], 'a shared-layer track passes the validator');
}

# --- a class with no jbrowse2 store dies naming itself ---
{
  my $track = track(dataset => 'DS', organism => 'intPfal', label => 'Low Complexity Regions', store => undef);
  eval { $track->getConfigurationObject() };
  like($@, qr/^ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig 'Low Complexity Regions' has no jbrowse2 store/,
       'dies naming the class and the label');
}

# --- decision 0008 (corrected): v5 DNA-seq is per-isolate coverage + normalised coverage ---
{
  require ApiCommonModel::Model::JbrowseDnaSeqTracks;

  my $ws = tempdir(CLEANUP => 1);
  foreach my $sample (qw(S1 S2)) {
    my $dir = "$ws/PlasmoDB/build-71/Pfal/dnaseq/bigwig/pfal3D7_DS_RSRC/$sample";
    make_path($dir);
    foreach my $suffix ('', '_normalisedCoverage', '_LOH', '_snpDensity', '_indelDensity') {
      open(my $fh, '>', "$dir/$sample$suffix.bw") or die $!;
      close $fh;
    }
  }

  {
    package FakeJBrowseUtil;
    sub new { bless {}, shift }
    sub getDatasetProperties {
      return {organism => {organismNameForFiles => 'Pfal'},
              dnaseq => {pfal3D7_DS_RSRC => {datasetDisplayName => 'DS', category => 'Genetic Variation',
                                             subCategory => 'DNA-Seq'}}};
    }
  }

  my $produce = sub {
    my $result = {tracks => []};
    ApiCommonModel::Model::JbrowseDnaSeqTracks::processOrganism(
      'intPfal', 'PlasmoDB', 71, $ws, $_[0], FakeJBrowseUtil->new(), $result);
    return $result->{tracks};
  };

  my $jb2 = $produce->('jbrowse2');
  is_deeply([map { $_->{trackId} } @$jb2],
            [qw(pfal3D7_DS_RSRC_S1 pfal3D7_DS_RSRC_S1_normalisedCoverage pfal3D7_DS_RSRC_S1_LOH
                pfal3D7_DS_RSRC_S1_variantDensity
                pfal3D7_DS_RSRC_S2 pfal3D7_DS_RSRC_S2_normalisedCoverage pfal3D7_DS_RSRC_S2_LOH
                pfal3D7_DS_RSRC_S2_variantDensity)],
            'jbrowse2: every measure per isolate - coverage, normalised, LOH, density group');
  my ($density) = grep { $_->{trackId} eq 'pfal3D7_DS_RSRC_S1_variantDensity' } @$jb2;
  is_deeply([map { $_->{bigWigLocation}{uri} } @{$density->{adapter}{subadapters}}],
            ['/a/service/jbrowse/store?data=Pfal/dnaseq/bigwig/pfal3D7_DS_RSRC/S1/S1_snpDensity.bw',
             '/a/service/jbrowse/store?data=Pfal/dnaseq/bigwig/pfal3D7_DS_RSRC/S1/S1_indelDensity.bw'],
            'the density group overlays SNP and indel density from store locations');
  is($jb2->[0]{adapter}{bigWigLocation}{uri},
     '/a/service/jbrowse/store?data=Pfal/dnaseq/bigwig/pfal3D7_DS_RSRC/S1/S1.bw',
     'raw coverage has a store location');
  is_deeply(ApiCommonModel::Model::JBrowseConfigRelease::Validate->validate({
              assemblies => [{name => 'pfal3D7', sequence => {adapter => {
                type => 'IndexedFastaAdapter',
                fastaLocation => {uri => '/a/service/jbrowse/store?data=g.fa'},
                faiLocation => {uri => '/a/service/jbrowse/store?data=g.fa.fai'}}}}],
              tracks => $jb2}),
            [], 'and every one passes the validator');

  my $jb1 = $produce->('jbrowse');
  is(scalar(@$jb1), 8, 'jbrowse still gets all three measures and the density group per isolate');
  ok(scalar(grep { $_->{label} =~ /_LOH$/ } @$jb1) == 2, 'including LOH');
}

# --- the jbrowse application type never sees the contract ---
{
  my $bw = store('BigWigStore', 'jbrowse', 'P/a.bw');
  my $track = track(app => 'jbrowse', dataset => 'DS', organism => 'intPfal', label => 'a - b', store => $bw);
  $track->setDisplayType('JBrowse/View/Track/Wiggle/XYPlot');
  my $obj = $track->getConfigurationObject();
  is($obj->{label}, 'a - b', 'jbrowse label is the raw label');
  ok(!exists($obj->{trackId}) && !exists($obj->{assemblyNames}), 'no jbrowse2 keys on a jbrowse object');
}

# --- protein-coordinate tracks belong to <abbrev>_protein ---
{
  my $gff = store('GFFStore', 'jbrowse2', 'Pfal/genomeAndProteome/gff/iprscan_out.gff.gz');
  my $make = sub {
    my (%a) = @_;
    my $t = "${NS}::TrackConfig"->new({application_type => 'jbrowse2', organism_abbrev => 'intPfal',
                                       sequence_type => 'protein', category => 'Protein', store => $gff,
                                       id => 'Display', %a});
    return $t->getConfigurationObject();
  };

  my $obj = $make->(label => 'InterproDomains');
  is($obj->{trackId}, 'pfal3D7_protein_InterproDomains', 'protein trackId is <abbrev>_protein_<name>');
  is_deeply($obj->{assemblyNames}, ['pfal3D7_protein'], 'and names the protein assembly');
  is($make->(label => 'pfal3D7_massSpec_X_RSRC', dataset_name => 'pfal3D7_massSpec_X_RSRC')->{trackId},
     'pfal3D7_protein_massSpec_X_RSRC', 'a dataset label already carrying the genome abbrev is not prefixed twice');
}

# --- a feature store with no track type is a FeatureTrack on LinearBasicDisplay ---
{
  my $bed = store('BedStore', 'jbrowse2', 'Pfal/genomeAndProteome/bed/tandemRepeats.bed.gz');
  is($bed->getStoreType(), 'BedTabixAdapter', 'jbrowse2 BED adapter has its v5 spelling');
  is(store('BedStore', 'jbrowse', 'P/a.bed.gz')->getStoreType(), 'JBrowse/Store/SeqFeature/BEDTabix',
     'jbrowse BED store type is unchanged');
  my $obj = "${NS}::TrackConfig"->new({application_type => 'jbrowse2', organism_abbrev => 'intPfal',
                                       category => 'Sequence Analysis', store => $bed, label => 'Tandem Repeats',
                                       id => 'Tandem Repeats'})->getConfigurationObject();
  is($obj->{type}, 'FeatureTrack', 'type defaults to FeatureTrack');
  is_deeply([map { $_->{type} } @{$obj->{displays}}], ['LinearBasicDisplay'], 'display defaults to LinearBasicDisplay');
  is_deeply($obj->{adapter}{index}{location}{uri},
            '/a/service/jbrowse/store?data=Pfal/genomeAndProteome/bed/tandemRepeats.bed.gz.tbi', 'with its .tbi');
}

# --- every class the organism-specific producers use emits a conforming jbrowse2 object ---
{
  my %classes = (
    InterproDomainsTrackConfig => ['P/iprscan_out.gff.gz', 'protein'], SignalPeptideTrackConfig => ['P/signalP.gff.gz', 'protein'],
    TmhmmTrackConfig => ['P/tmhmm.gff.gz', 'protein'], ExportPredTrackConfig => ['P/exportpred.gff.gz', 'protein'],
    IedbTrackConfig => ['P/iedb.gff.gz', 'protein'], UnifiedPostTranslationalMod => ['P/ptm.gff.gz', 'protein'],
    HydropathyTrackConfig => ['P/hydropathy.bw', 'protein'], SecondaryStructureTrackConfig => ['P/psipred_helix.bw', 'protein'],
    LowComplexityTrackConfig => ['P/lowComplexity.bed.gz', 'genome'], RepeatsTrackConfig => ['P/tandemRepeats.bed.gz', 'genome'],
    UnifiedMassSpecTrackConfig => ['P/unifiedGenomicMassSpec.gff.gz', 'genome'],
    LongReadRNASeqTrackConfig => ['P/models.gff.gz', 'genome'], RNASeqJunctionTrackConfig => ['P/junctions.gff.gz', 'genome'],
  );
  my $assemblies = [map { {name => $_, sequence => {adapter => {type => 'IndexedFastaAdapter',
                      fastaLocation => {uri => '/a/service/jbrowse/store?data=g.fa'},
                      faiLocation => {uri => '/a/service/jbrowse/store?data=g.fa.fai'}}}} } qw(pfal3D7 pfal3D7_protein)];
  foreach my $class (sort keys %classes) {
    my ($path, $sequence) = @{$classes{$class}};
    eval "require ${NS}::$class; 1" or die $@;
    my $obj = eval {
      "${NS}::$class"->new({application_type => 'jbrowse2', project_name => 'PlasmoDB', build_number => 71,
                            relative_path_to_file => $path, organism_abbrev => 'intPfal',
                            ($sequence eq 'protein' ? (sequence_type => 'protein') : ()),
                            key => "$class key", label => "$class label", summary => 's',
                            type => 'EbrcTracks/View/Track/GFFByReadCount'})->getConfigurationObject();
    };
    ok($obj, "$class: emits an object") or diag $@;
    is_deeply(ApiCommonModel::Model::JBrowseConfigRelease::Validate->validate(
                {assemblies => $assemblies, tracks => [$obj]}), [], "$class: conforms")
      if($obj);
  }

  foreach my $class (qw(ReferenceSequenceTrackConfig ProteinRefSeqTrackConfig ApolloGffTrackConfig)) {
    eval "require ${NS}::$class; 1" or die $@;
    my $obj = "${NS}::$class"->new({application_type => 'jbrowse2', project_name => 'PlasmoDB', build_number => 71,
                                     relative_path_to_file => 'P/x', organism_abbrev => 'intPfal',
                                     key => 'k', label => 'l'})->getConfigurationObject();
    is($obj, undef, "$class: no jbrowse2 track (the assembly, or REST-only Apollo, covers it)");
  }
}

# --- styling: each producer binds its VEuPathDBDisplay function, or a literal, in the README slot ---
{
  my $T = "${NS}::TrackConfig";
  is($T->veupathJexl('veupathStrandColor', 'deepskyblue', 'pink'),
     "jexl:veupathStrandColor(feature, 'deepskyblue', 'pink')", 'veupathJexl: feature first, literals quoted');
  is($T->veupathJexl('veupathGsnapIntronColor'), 'jexl:veupathGsnapIntronColor(feature)', 'veupathJexl: no arguments');
  ok(!eval { $T->veupathJexl('strandColor'); 1 }, 'veupathJexl refuses a function outside the allowlist');
  ok(!eval { $T->veupathJexl('veupathStrandColor', "it's", 'b'); 1 }, 'veupathJexl refuses a quote in a literal');

  my $new = sub {
    my ($class, $appType, $path) = @_;
    eval "require ${NS}::$class; 1" or die $@;
    return "${NS}::$class"->new({application_type => $appType, project_name => 'PlasmoDB', build_number => 71,
                                 relative_path_to_file => $path, organism_abbrev => 'intPfal',
                                 key => "$class key", label => "$class label", summary => 's'});
  };
  my $make = sub { $new->(@_)->getConfigurationObject() };

  my %fill = (
    LongReadRNASeqTrackConfig  => "jexl:veupathStrandColor(feature, '#6666FF', '#F18F74')",
    EstTrackConfig             => "jexl:veupathStrandColor(feature, 'deepskyblue', 'pink')",
    NrdbProteinTrackConfig     => "jexl:veupathStrandColor(feature, 'mediumblue', 'crimson')",
    OrfTrackConfig             => "jexl:veupathStrandColor(feature, 'dodgerblue', 'mediumvioletred')",
    HaplotypeBlockTrackConfig  => 'jexl:veupathHaplotypeColor(feature)',
    BindingSitesTrackConfig    => 'jexl:veupathBindingSiteColor(feature)',
    InterproDomainsTrackConfig => 'jexl:veupathInterproColor(feature)',
    SignalPeptideTrackConfig   => 'jexl:veupathSignalpColor(feature)',
    IedbTrackConfig            => 'jexl:veupathIedbColor(feature)',
    UnifiedPostTranslationalMod => 'jexl:veupathPostTranslationalModColor(feature)',
    UnifiedMassSpecTrackConfig => 'gray',
    ChipChipPeakTrackConfig    => '#B84C00',
  );
  foreach my $class (sort keys %fill) {
    my $obj = $make->($class, 'jbrowse2', 'P/x.gff.gz');
    is($obj->{displays}[0]{type}, 'LinearBasicDisplay', "$class: LinearBasicDisplay");
    is_deeply($obj->{displays}[0]{encoding}, {color => {value => $fill{$class}}}, "$class: encoding.color.value");

    my $jb1Style = $new->($class, 'jbrowse', 'P/x.gff.gz')->getJBrowseStyle() || {};
    ok(!grep({ defined($_) && !ref($_) && /jexl:/ } values %$jb1Style), "$class: jbrowse style carries no v5 jexl")
      or diag explain $jb1Style;
  }

  my $smoothed = $make->('ChipChipSmoothedTrackConfig', 'jbrowse2', 'P/s.bw');
  is($smoothed->{displays}[0]{encoding}{color}{value}, '#B84C00', 'ChIP-chip smoothed: literal colour');
  is($smoothed->{displays}[0]{encoding}{y}{scale}{type}, 'log', 'beside the y scale it already had');

  my $genes = $T->new({application_type => 'jbrowse2', organism_abbrev => 'intPfal', category => 'Gene Models',
                       store => store('GFFStore', 'jbrowse2', 'P/annotated_transcripts.gff.gz'),
                       label => 'GeneModels', id => 'Annotated Transcripts',
                       jbrowse2_color => $T->veupathJexl('veupathProcessedTranscriptColor')})->getConfigurationObject();
  is($genes->{displays}[0]{encoding}{color}{value}, 'jexl:veupathProcessedTranscriptColor(feature)',
     'gene models: veupathProcessedTranscriptColor');

  my $junctions = $make->('RNASeqJunctionTrackConfig', 'jbrowse2', 'P/junctions.gff.gz');
  is_deeply($junctions->{displays}, [{
    type => 'LinearMarkDisplay', displayId => "$junctions->{trackId}-LinearMarkDisplay",
    marks => [{mark => 'link', encoding => {
      color       => {value => 'jexl:veupathGsnapIntronColor(feature)'},
      strokeWidth => {field => 'jexl:veupathGsnapIntronLineThickness(feature)',
                      scale => {type => 'linear', domainMin => 2, domainMax => 6, range => [2, 6]}},
    }}],
  }], 'junctions: one link mark, gsnap colour and identity-scaled thickness');

  my $variants = $make->('VariantTrackConfig', 'jbrowse2', 'P/merged.ann.vcf.gz');
  is_deeply($variants->{displays}, [{
    type => 'LinearMarkDisplay', displayId => "$variants->{trackId}-LinearMarkDisplay",
    marks => [{mark => 'point', transform => [{type => 'pileup'}],
               encoding => {y => 'row', shape => {value => 'diamond'},
                            color => {value => 'jexl:veupathVariantEffectColor(feature)'}}}],
  }], 'merged VCF: stacked diamond points coloured by variant effect');

  my $perSample = $make->('VcfTrackConfig', 'jbrowse2', 'P/sample.vcf.gz');
  is_deeply($perSample->{displays}[0]{marks}[0]{encoding}, {y => 'row', shape => {value => 'diamond'}},
            'per-sample VCF: the same mark, stock colour (JBrowse 1 set none)');

  my $assemblies = [{name => 'pfal3D7', sequence => {adapter => {type => 'IndexedFastaAdapter',
                      fastaLocation => {uri => '/a/service/jbrowse/store?data=g.fa'},
                      faiLocation => {uri => '/a/service/jbrowse/store?data=g.fa.fai'}}}}];
  is_deeply(ApiCommonModel::Model::JBrowseConfigRelease::Validate->validate(
              {assemblies => $assemblies, tracks => [$genes, $junctions, $variants]}), [],
            'gene models, junctions and variants conform');
}

# --- wiggle displays use v5 keys, never the retired spellings ---
{
  require ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigTrackConfig;
  my $multi = "${NS}::MultiBigWigTrackConfig::XY"->new({
    application_type => 'jbrowse2', project_name => 'PlasmoDB', build_number => 71, organism_abbrev => 'intPfal',
    dataset_name => 'pfal3D7_DS_rnaSeq_RSRC', study_display_name => 'DS', category => 'Transcriptomics',
    multi_urls => [{relative_path_to_file => 'P/a.bw', name => 'a', color => 'red'}],
  })->getConfigurationObject();
  my $display = $multi->{displays}[0];
  is($display->{type}, 'LinearWiggleDisplay', 'multi-wiggle uses LinearWiggleDisplay');
  is($display->{rows}, 'source', 'one row per source');
  ok(!grep({ exists $display->{$_} } qw(defaultRendering scaleType minScore maxScore)), 'no retired keys')
    or diag explain $display;
  is($display->{encoding}{y}{scale}{type}, 'log', 'the y scale is an encoding');
}

done_testing();
