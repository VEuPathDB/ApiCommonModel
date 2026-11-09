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

# --- decision 0008: the curated v5 set has no per-isolate DNA-seq tracks ---
{
  require ApiCommonModel::Model::JbrowseDnaSeqTracks;
  my $result = {tracks => []};
  ApiCommonModel::Model::JbrowseDnaSeqTracks::processOrganism(
    'intPfal', 'PlasmoDB', 71, '/nowhere', 'jbrowse2', undef, $result);
  is_deeply($result->{tracks}, [], 'dnaseq producer emits nothing for jbrowse2 (and reads nothing)');
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

done_testing();
