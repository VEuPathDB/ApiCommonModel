package ApiCommonModel::Model::JbrowseDnaSeqTracks;

use strict;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::JBrowseTrackConfig::SingleCoverageTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::VcfTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::DatasetConfig;
use File::Basename;

# DNASeq jbrowse tracks.
#
# Division of knowledge, which is the whole point of how this module is shaped:
#
#   presenter (dnaseq:: props in datasetAndPresenterProps.conf, written by the
#             IsolatesHTS injector) -> display name, summary, attribution, category
#   filesystem (the webservices tree the dnaseq pipeline writes) -> which samples an
#             experiment has, and which measures each of those samples has
#
# Nothing declares the sample list any more. It used to be injected at build time from a
# DB-derived query, which meant the track list and the files it pointed at had separate
# sources of truth; they diverged, and the endpoint silently served an empty track list.
# Reading the tree is what makes "a track exists" and "its file exists" the same fact.
#
# It is also the only workable source for LOH, which the pipeline emits per sample only
# for diploid organisms - tbruTREU927 has _LOH.bw, the haploid pfal3D7 does not. No
# per-dataset property could express that, since it varies by organism, not by dataset.
#
# KNOWN LIMITATION, JBrowse2: SingleCoverageTrackConfig::getJBrowse2Object returns undef
# unless the caller is the ::CNV subclass, so under application_type 'jbrowse2' (the
# jbrowse2Config script, not the /service/jbrowse/dnaseq endpoint, which is 'jbrowse')
# only the normalisedCoverage measure yields a track and the other four are dropped.
# That predates this rewrite and is recorded here rather than worked around, because
# picking the JBrowse2 presentation for four new measures is a product decision.

# The per-sample measures, keyed by the filename suffix the pipeline writes. A measure
# absent for a sample is normal and silent. Order here is the order tracks appear.
#
# max scores are display choices, picked from the b71 data rather than guessed. Observed
# (pfal3D7/707A and tbruTREU927/STIB247 respectively):
#
#   coverage            mean 28 / 48,    max 3367 / 50590   -> log, class default max
#   normalisedCoverage  mean 1.1 / 2.3,  max 108 / 962      -> linear, 5 (1 == expected ploidy)
#   LOH                 -    / 2.2,      -   / 62           -> linear, 25
#
# snpDensity (max 51/98) and indelDensity (max 4/19) are not here: they share one per-sample
# overlaid track instead, which autoscales - see @DENSITY_GROUP below.
#
# These ranges are GLOBAL: one fixed min/max per measure, applied to every sample of every
# organism. Nothing is derived per file and nothing autoscales. Note the two organisms
# sampled above disagree by more than an order of magnitude on coverage (3367 vs 50590), so
# a global range certainly clips somewhere. Every measure carries a red clip marker so a
# window driven off the top of the scale says so on screen instead of quietly flattening.
# If that proves too coarse, JBrowse 1 wiggle supports autoscale=local (see
# MultiBigWigTrackConfig::XY) - it would need exposing through SingleCoverageTrackConfig.

# Pixel height of every bigwig track. Overrides CoverageTrackConfig's default of 40.
my $BIGWIG_TRACK_HEIGHT = 60;

my @MEASURES = (
  { suffix                => '',
    display_name_suffix   => 'Coverage',
    track_type_display    => 'Coverage',
    scale                 => 'log',
    # Set explicitly even though it equals the class default: the setter does
    # "$value + 0", so passing undef both warns (and this process's stderr is merged
    # into the JSON response) and stores 0.
    cov_max_score_default => 1000,
    color                 => 'black',
  },
  { suffix                => '_normalisedCoverage',
    display_name_suffix   => 'Coverage normalised to chromosome copy number (ploidy)',
    track_type_display    => 'Coverage (ploidy Normalized)',
    scale                 => 'linear',
    cov_max_score_default => 5,
    color                 => 'black',
    # ::CNV is the subclass that opts this measure into a JBrowse2 configuration object;
    # the plain class returns undef there, on the grounds that JBrowse2 prefers its
    # multi-coverage handling for the RNASeq/ChIPSeq cases.
    class                 => 'ApiCommonModel::Model::JBrowseTrackConfig::SingleCoverageTrackConfig::CNV',
  },
  { suffix                => '_LOH',
    display_name_suffix   => 'Loss of heterozygosity',
    track_type_display    => 'Loss of heterozygosity',
    scale                 => 'linear',
    cov_max_score_default => 25,
    color                 => 'darkgreen',
  },
);

my $DEFAULT_MEASURE_CLASS = 'ApiCommonModel::Model::JBrowseTrackConfig::SingleCoverageTrackConfig';

# The two density measures share ONE PER-SAMPLE overlaid XY track. They can share a y-axis
# honestly: their maxima sit within ~5x of each other (snp 51-98, indel 4-19), and ::XY sets
# autoscale=local so neither is pinned to a fixed ceiling.
#
# Scope is deliberately ONE SAMPLE per track. Pooling every sample of an experiment into a
# single plot was tried and reverted: at a few hundred overlaid subtracks the result is
# unreadable, because only two colours are available (one per measure) so individual samples
# are indistinguishable and the traces simply pile up.
#
# Coverage is deliberately not grouped at all. Raw coverage runs to 3367-50590 against
# normalised coverage's ~5 - a ~200x gap that would render the normalised track as a flat
# line against the same axis - so those two stay as individual tracks.
#
# Order here is the order subtracks appear; colours are per subtrack.
my @DENSITY_GROUP = (
  { suffix => '_snpDensity',   name => 'SNP density',   color => 'blue' },
  { suffix => '_indelDensity', name => 'Indel density', color => 'purple' },
);

my $DENSITY_GROUP_CLASS = 'ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigTrackConfig::XY';

sub processOrganism {
  my ($organismAbbrev, $projectName, $buildNumber, $webservicesDir, $applicationType, $jbrowseUtil, $result) = @_;

  my $datasetProps = $jbrowseUtil->getDatasetProperties();

  my $publicAbbrevForFiles = $datasetProps->{organism}->{organismNameForFiles};

  my $dnaSeqDatasets = $datasetProps->{dnaseq} ? $datasetProps->{dnaseq} : {};

  # No dnaseq presenters for this organism: legitimately nothing to serve.
  return unless(keys %$dnaSeqDatasets);

  my $dnaSeqDir = "$webservicesDir/$projectName/build-$buildNumber/$publicAbbrevForFiles/dnaseq";
  my $bigwigDir = "$dnaSeqDir/bigwig";

  # This organism has dnaseq datasets, so its files are supposed to be here. If the
  # directory is missing the mirror is unreachable or the build is incomplete, and that
  # must not look the same as "this organism has no DNASeq data" - serving an empty track
  # list for an unreadable mirror is exactly the failure this rewrite exists to fix.
  unless(-d $bigwigDir) {
    die "DNASeq bigwig directory not found for $organismAbbrev, but "
      . scalar(keys %$dnaSeqDatasets)
      . " dnaseq dataset(s) are declared for it: $bigwigDir\n";
  }

  my $filesByDatasetAndSample = &indexBigwigFiles($bigwigDir);

  foreach my $dataset (sort keys %$dnaSeqDatasets) {
    my $samples = $filesByDatasetAndSample->{$dataset};

    # A declared dataset with no files on disk. Benign curation drift: presenters are
    # deliberately a superset of what a given build loaded. Skip it rather than fail.
    next unless($samples);

    my $datasetConfig = ApiCommonModel::Model::JBrowseTrackConfig::DatasetConfig->new({
      dataset_name       => $dataset,
      study_display_name => $dnaSeqDatasets->{$dataset}->{datasetDisplayName},
      category           => $dnaSeqDatasets->{$dataset}->{category},
      subcategory        => $dnaSeqDatasets->{$dataset}->{subCategory},
      attribution        => $dnaSeqDatasets->{$dataset}->{shortAttribution},
      summary            => $dnaSeqDatasets->{$dataset}->{summary},
      application_type   => $applicationType,
      organism_abbrev    => $organismAbbrev,
    });

    foreach my $sampleName (sort keys %$samples) {
      foreach my $measure (@MEASURES) {
        my $fileName = $samples->{$sampleName}->{$measure->{suffix}};
        next unless($fileName);

        my $class = $measure->{class} ? $measure->{class} : $DEFAULT_MEASURE_CLASS;

        my $track = $class->new({
          dataset_config         => $datasetConfig,
          project_name           => $projectName,
          build_number           => $buildNumber,
          application_type       => $applicationType,
          relative_path_to_file  => "$publicAbbrevForFiles/dnaseq/bigwig/$dataset/$sampleName/$fileName",
          display_name           => $sampleName,
          display_name_suffix    => $measure->{display_name_suffix},
          track_type_display     => $measure->{track_type_display},
          # label is the JBrowse track id and must be unique across the whole response.
          # Built from dataset + sample + measure so it is unique by construction; sample
          # names are not guaranteed distinct between experiments of one organism.
          label                  => $dataset . "_" . $sampleName . $measure->{suffix},
          scale                  => $measure->{scale},
          color                  => $measure->{color},
          cov_max_score_default  => $measure->{cov_max_score_default},
          clip_marker_color      => 'red',
          height                 => $BIGWIG_TRACK_HEIGHT,
        })->getConfigurationObject();

        push @{$result->{tracks}}, $track if($track);
      }

      &addDensityGroupTrack($dataset, $sampleName, $samples->{$sampleName}, $datasetConfig,
                            $dnaSeqDatasets->{$dataset}->{datasetDisplayName}, $projectName,
                            $buildNumber, $applicationType, $publicAbbrevForFiles, $result);
    }
  }

  &addMergedVcfTrack($organismAbbrev, $projectName, $buildNumber, $applicationType,
                     $publicAbbrevForFiles, $dnaSeqDir, $result);
}


# One overlaid XY track per SAMPLE carrying that sample's two density measures. Built from
# whichever of the two exist, so a sample with only one still gets a track rather than being
# dropped; if neither exists there is nothing to draw.
#
# Subtrack names are just the measure - the track's own key already names the sample, and
# with one sample per track colour alone distinguishes the two traces.
sub addDensityGroupTrack {
  my ($dataset, $sampleName, $filesBySuffix, $datasetConfig, $studyDisplayName, $projectName,
      $buildNumber, $applicationType, $publicAbbrevForFiles, $result) = @_;

  my @multiUrls;

  foreach my $measure (@DENSITY_GROUP) {
    my $fileName = $filesBySuffix->{$measure->{suffix}};
    next unless($fileName);

    push @multiUrls, {
      relative_path_to_file => "$publicAbbrevForFiles/dnaseq/bigwig/$dataset/$sampleName/$fileName",
      name                  => $measure->{name},
      color                 => $measure->{color},
    };
  }

  return unless(@multiUrls);

  my $track = $DENSITY_GROUP_CLASS->new({
    dataset_config   => $datasetConfig,
    project_name     => $projectName,
    build_number     => $buildNumber,
    application_type => $applicationType,
    multi_urls       => \@multiUrls,
    display_name     => $sampleName,
    scale            => 'linear',
    height           => $BIGWIG_TRACK_HEIGHT,
    # Unique per sample; every label this class derives itself is keyed on the dataset, so
    # all of an experiment's samples would otherwise collide on one JBrowse track id.
    label            => $dataset . "_" . $sampleName . "_variantDensity",
    id               => "$studyDisplayName - $sampleName SNP and indel density",
    # dnaseq has no unique/non-unique read split, so do not claim one.
    has_alignment    => 0,
  });

  # Set after construction: ::XY sets its own trackTypeDisplay after SUPER::new, so a
  # constructor arg would be clobbered.
  $track->setTrackTypeDisplay('SNP and indel density');

  my $configObject = $track->getConfigurationObject();

  push @{$result->{tracks}}, $configObject if($configObject);
}


# Index every bigwig under the organism's dnaseq tree in a single glob, rather than one
# opendir per sample - an organism can carry well over 500 samples and this runs per
# request.
#
# Layout: dnaseq/bigwig/<datasetName>/<sampleName>/<sampleName><suffix>.bw
sub indexBigwigFiles {
  my ($bigwigDir) = @_;

  my $index = {};

  foreach my $path (glob("$bigwigDir/*/*/*.bw")) {
    my $fileName = basename($path);
    my $sampleDir = dirname($path);
    my $sampleName = basename($sampleDir);
    my $datasetName = basename(dirname($sampleDir));

    # The suffix is whatever follows the sample name, so '<s>.bw' yields '' (raw coverage)
    # and '<s>_snpDensity.bw' yields '_snpDensity'. A file not named for the sample dir it
    # sits in is not a measure of that sample, so it has no track.
    my ($suffix) = $fileName =~ /^\Q$sampleName\E(.*)\.bw$/;
    next unless(defined $suffix);

    $index->{$datasetName}->{$sampleName}->{$suffix} = $fileName;
  }

  return $index;
}


# The merged, annotated VCF is one file per organism - a merge across every dnaseq
# experiment - so it is emitted once, outside the per-dataset loop, and has no single
# presenter to draw display metadata from. This is the genome-browser face of the Variant
# record.
sub addMergedVcfTrack {
  my ($organismAbbrev, $projectName, $buildNumber, $applicationType,
      $publicAbbrevForFiles, $dnaSeqDir, $result) = @_;

  my $vcfFile = "$dnaSeqDir/vcf/merged.ann.vcf.gz";

  # Unlike the bigwig directory this is not required: an organism can have DNASeq coverage
  # without a merged variant call set.
  return unless(-e $vcfFile);

  my $track = ApiCommonModel::Model::JBrowseTrackConfig::VcfTrackConfig->new({
    project_name          => $projectName,
    build_number          => $buildNumber,
    application_type      => $applicationType,
    organism_abbrev       => $organismAbbrev,
    relative_path_to_file => "$publicAbbrevForFiles/dnaseq/vcf/merged.ann.vcf.gz",
    key                   => "Short variants from all DNA-Seq samples",
    label                 => "${organismAbbrev}_dnaseq_merged_short_variants",
    # Both resolved per feature from functions.conf: diamond for SNVs and a box for
    # indels, coloured by the most severe snpEff effect class across the variant's ANN
    # entries.
    glyph                 => "{variantGlyphFxn}",
    color                 => "{variantEffectColorFxn}",
    study_display_name    => "All DNA-Seq samples",
    # The summary doubles as the track's legend: shape and colour are the only channels
    # distinguishing variant type and effect on screen, so what they mean is spelled out
    # rather than left to be inferred.
    summary               => "Single nucleotide variants and short indels called across "
                           . "every DNA-Seq sample for this organism, merged into one "
                           . "annotated call set. Substitutions are drawn as diamonds and "
                           . "indels as boxes. Colour shows the most severe predicted "
                           . "effect: red = truncation or stop gained, purple = "
                           . "non-synonymous, green = synonymous, blue = intron or other.",
    # Empty rather than undef on purpose: getMetadata uri_unescapes attribution
    # unconditionally, and an undef there warns - which, because the service merges this
    # process's stderr into its stdout, would corrupt the JSON response.
    attribution           => "",
    track_type_display    => "Merged VCF",
  })->getConfigurationObject();

  push @{$result->{tracks}}, $track if($track);
}

1;

