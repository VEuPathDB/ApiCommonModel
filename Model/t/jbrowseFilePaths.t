use strict;
use warnings;
use Test::More tests => 5;
use URI::Escape qw(uri_unescape);
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::JbrowseOrgSpecificNaTracks;

# Guards OutreachBugsAndFeatures#122: JBrowse tracks whose urlTemplate names a
# file that is not on the webservices mirror. The store service answers those
# with HTTP 500 ("File ... does not exist or is size 0"), shown to users as a
# red error box in place of the track.
#   - antiSMASH: the file was sorted.gff.gz in build-70 and became
#     antismash.gff.gz in build-71, while the code kept the old name.
#   - VCF: files live under <org>/prealigned/vcf/ since build-70, while the
#     code built <org>/vcf/.
# Each case checks the generated urlTemplate against the real mirror.

my $mirror = $ENV{WEBSERVICEMIRROR} || '/var/www/Common/apiSiteFilesMirror/webServices';
my $build  = 71;

sub fileForUrl {
  my ($project, $url) = @_;
  my ($data) = $url =~ /store\?data=([^&]+)/;
  return undef unless $data;
  return "$mirror/$project/build-$build/" . uri_unescape($data);
}

SKIP: {
  skip "requires the webservices mirror ($mirror/FungiDB/build-$build not found)", 3
    unless -d "$mirror/FungiDB/build-$build";

  my $result = { tracks => [] };
  ApiCommonModel::Model::JbrowseOrgSpecificNaTracks::addAntismash(
    $result, 'AclavatusNRRL1', $mirror, 'FungiDB', 'jbrowse', $build
  );
  is(scalar(@{$result->{tracks}}), 1, "antiSMASH track is produced when its file exists");

  my $file = fileForUrl('FungiDB', $result->{tracks}[0]{urlTemplate} || '');
  ok($file && -s $file, "antiSMASH urlTemplate resolves to a file on the mirror")
    or diag("missing: " . ($file // '<no store url>'));

  my $none = { tracks => [] };
  ApiCommonModel::Model::JbrowseOrgSpecificNaTracks::addAntismash(
    $none, 'NoSuchOrganismForTest', $mirror, 'FungiDB', 'jbrowse', $build
  );
  is(scalar(@{$none->{tracks}}), 0, "no antiSMASH track when the organism has no antiSMASH file");
}

SKIP: {
  skip "requires the webservices mirror ($mirror/VectorBase/build-$build not found)", 2
    unless -d "$mirror/VectorBase/build-$build";

  my $dataset = 'agamPEST_VBP0000002_MR4_colony_G3_ebi_VCF_RSRC';
  my $props = { vcffile => { $dataset => { datasetName => $dataset,
                                           datasetDisplayName => 'MR4 colony G3',
                                           summary => 'test' } } };
  my $result = { tracks => [] };
  ApiCommonModel::Model::JbrowseOrgSpecificNaTracks::addVCF(
    undef, $result, $props, 'AgambiaePEST', 'agamPEST', 'VectorBase', $build, 'jbrowse'
  );
  is(scalar(@{$result->{tracks}}), 1, "one VCF track is produced");

  my $file = fileForUrl('VectorBase', $result->{tracks}[0]{urlTemplate} || '');
  ok($file && -s $file, "VCF urlTemplate resolves to a file on the mirror")
    or diag("missing: " . ($file // '<no store url>'));
}
