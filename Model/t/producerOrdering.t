use strict;
use warnings;
use lib $ENV{GUS_HOME} . "/lib/perl";

use File::Path qw(make_path);
use File::Temp;
use JSON;
use Test::More;
use ApiCommonModel::Model::JbrowseOrgSpecificNaTracks;
use ApiCommonModel::Model::JbrowseOrgSpecificAaTracks;

# The track producers walk dataset property hashes, so an unsorted loop makes track
# order depend on Perl's per-process hash seed. Each producer runs here in child
# processes under different PERL_HASH_SEEDs, and their output must be byte-identical.

my $ORG = 'pfal3D7';
my $DATASETS = 16;
my @SEEDS = (1, 2, 3);
my @APP_TYPES = ('jbrowse', 'jbrowse2');

sub datasetProperties {
  my (%props, %all);
  foreach my $i (1 .. $DATASETS) {
    my $vcf = "${ORG}_exp${i}_ebi_VCF_RSRC";
    $props{vcffile}{$vcf} = {datasetName => $vcf, datasetDisplayName => "VCF $i", summary => "vcf $i"};

    my $ms = "${ORG}_massSpec_exp${i}_RSRC";
    $props{protexpmassspec}{$ms} = {name => "exp$i", datasetDisplayName => "Mass spec $i", presenterId => "DS_ms$i",
                                    datasetPresenterId => "DS_ms$i", datasetClassCategory => 'Proteomics',
                                    datasetExtdbName => $ms, summary => "ms $i", shortAttribution => "Lab $i"};

    my $nc = "${ORG}_smallNcRna_exp${i}_RSRC";
    $props{smallncrnaseq}{$nc} = {experimentName => "Lab${i}_Strain${i}_ncRNA", datasetDisplayName => "ncRNA $i",
                                  summary => "nc $i", shortAttribution => "Lab $i"};

    my $cie = "${ORG}_clonedInsertEnds_exp${i}_RSRC";
    $props{clonedinsertends}{$cie} = {datasetName => $cie, datasetDisplayName => "Cloned ends $i",
                                      datasetPresenterId => "DS_cie$i", summary => "cie $i", shortAttribution => "Lab $i"};

    my $lr = "${ORG}_nanopore_longReadRnaSeq_exp${i}_RSRC";
    $props{longreadrnaseq}{$lr} = {datasetName => $lr, datasetDisplayName => "Long read $i",
                                   datasetPresenterId => "DS_lr$i", summary => "lr $i", shortAttribution => "Lab $i"};
  }
  return \%props;
}

my ($FILES, $PROJECT, $BUILD) = ('Pfalciparum3D7', 'PlasmoDB', 71);

# The long-read producer reads one metadata.txt per dataset from the webServices
# tree. The parent writes them once; every child reads the same tree.
my $WS = $ENV{PRODUCER_ORDERING_WS};
unless (defined $WS) {
  $WS = File::Temp->newdir(CLEANUP => 1);
  foreach my $lr (sort keys %{datasetProperties()->{longreadrnaseq}}) {
    my $dir = "$WS/$PROJECT/build-$BUILD/$FILES/longReadRNASeq/bam/$lr";
    make_path($dir);
    open(my $fh, '>', "$dir/metadata.txt") or die "Cannot write $dir/metadata.txt: $!";
    print $fh "bam\t$lr.sample$_.bam\t$lr sample $_\n" foreach (1, 2);
    close $fh;
  }
}

my %PRODUCERS = (
  vcf              => sub { my ($r, $p, $app) = @_; ApiCommonModel::Model::JbrowseOrgSpecificNaTracks::addVCF(undef, $r, $p, $FILES, $ORG, $PROJECT, $BUILD, $app) },
  massSpecNa       => sub { my ($r, $p, $app) = @_; ApiCommonModel::Model::JbrowseOrgSpecificNaTracks::addProteinExpressionMassSpec($r, $p, $FILES, $ORG, $PROJECT, $BUILD, $app, $WS) },
  massSpecAa       => sub { my ($r, $p, $app) = @_; ApiCommonModel::Model::JbrowseOrgSpecificAaTracks::addProteinExpressionMassSpec($r, $p, $WS, $FILES, $PROJECT, $app, $BUILD, $ORG) },
  smallNcRna       => sub { my ($r, $p, $app) = @_; ApiCommonModel::Model::JbrowseOrgSpecificNaTracks::addSmallNcRnaSeq($p, $PROJECT, $BUILD, $FILES, $app, $r, $ORG) },
  clonedInsertEnds => sub { my ($r, $p, $app) = @_; ApiCommonModel::Model::JbrowseOrgSpecificNaTracks::addClonedInsertEnds($r, $p, $WS, $FILES, $PROJECT, $app, $BUILD, $ORG) },
  longReadRnaSeq   => sub { my ($r, $p, $app) = @_; ApiCommonModel::Model::JbrowseOrgSpecificNaTracks::addLongReadRNASeq($r, $p, $FILES, $WS, $PROJECT, $BUILD, $app, $ORG) },
);

if (defined $ENV{PRODUCER_ORDERING_CHILD}) {
  my ($name, $app) = split /:/, $ENV{PRODUCER_ORDERING_CHILD};
  my $result = {tracks => []};
  $PRODUCERS{$name}->($result, datasetProperties(), $app);
  print JSON->new->canonical->encode($result);
  exit 0;
}

sub runUnderSeed {
  my ($name, $app, $seed) = @_;
  local $ENV{PERL_HASH_SEED} = $seed;
  local $ENV{PERL_PERTURB_KEYS} = 2;
  local $ENV{PRODUCER_ORDERING_CHILD} = "$name:$app";
  local $ENV{PRODUCER_ORDERING_WS} = "$WS";
  open(my $fh, '-|', $^X, $0) or die "Cannot fork $^X $0: $!";
  local $/;
  my $out = <$fh>;
  close $fh;
  return ($? >> 8, $out);
}

SKIP: {
  skip "requires GUS_HOME", 1 unless $ENV{GUS_HOME};

  foreach my $name (sort keys %PRODUCERS) {
    foreach my $app (@APP_TYPES) {
      my @runs = map { [runUnderSeed($name, $app, $_)] } @SEEDS;
      my @failed = grep { $runs[$_][0] } 0 .. $#runs;
      ok(!@failed, "$name ($app) runs under every hash seed") or next;

      my $tracks = scalar @{decode_json($runs[0][1])->{tracks}};
      cmp_ok($tracks, '>=', $DATASETS, "$name ($app) emits a track per dataset");

      my @differ = grep { $runs[$_][1] ne $runs[0][1] } 1 .. $#runs;
      ok(!@differ, "$name ($app) output is identical under hash seeds @SEEDS")
        or diag("differs from seed $SEEDS[0] under seed(s) @SEEDS[@differ]");
    }
  }
}

done_testing();
