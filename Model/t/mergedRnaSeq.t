use strict;
use warnings;
use Test::More tests => 3;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::JbrowseOrgSpecificNaTracks;

# Guards against a0e116aa29 regressing: that commit switched
# addMergedRnaSeq() from filtering by $datasetProperties->{rnaseq} (the
# registered/public dataset list, sourced from datasetAndPresenterProps.conf)
# to a raw directory scan of bulkrnaseq/bigwig/. A directory existing on
# disk does not mean the dataset is meant to be public -- ToxoDB.xml has
# datasets that are deliberately internal-only or superseded (commented-out
# <datasetPresenter> blocks, kept only as <internalDataset> for provenance).
# The raw scan silently included those in the "combined RNAseq plot" served
# to every visitor, producing a plot that differs from the legacy
# (conf-filtered) site for the same organism/gene.

my $confFile = "$ENV{GUS_HOME}/lib/jbrowse/auto_generated/tgonME49/datasetAndPresenterProps.conf";

SKIP: {
  skip "requires a built gus_home with tgonME49's generated conf ($confFile not found)", 3
    unless -e $confFile;

  open(my $fh, '<', $confFile) or die "Cannot open $confFile: $!";
  my %rnaseq;
  while (my $line = <$fh>) {
    if ($line =~ /^rnaseq::([^:]+)::(\w+)=(.*)$/) {
      $rnaseq{$1}{$2} = $3;
    }
  }
  close($fh);

  ok(scalar(keys %rnaseq) > 0, "parsed at least one registered rnaseq dataset from the real conf");

  my $result = { tracks => [] };
  ApiCommonModel::Model::JbrowseOrgSpecificNaTracks::addMergedRnaSeq(
    $result, { rnaseq => \%rnaseq }, 'ToxoDB', 'TgondiiME49', 'tgonME49', 71
  );

  is(scalar(@{$result->{tracks}}), 1, "exactly one combined-RNAseq MultiBigWig track is produced");

  my @urlNames = map { $_->{name} } @{$result->{tracks}[0]{urlTemplates}};
  my @knownInternalOnly = ('DBP_Hehl-Grigg', 'White_paper_GT1_ebi', 'White_paper_ME49_ebi');
  my @leaked = grep { my $prefix = $_; grep { /\Q$prefix\E/ } @urlNames } @knownInternalOnly;

  is_deeply(\@leaked, [], "no internal-only/superseded datasets leak into the combined plot")
    or diag("leaked: @leaked");
}
