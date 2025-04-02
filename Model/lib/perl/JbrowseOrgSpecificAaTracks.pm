package ApiCommonModel::Model::JbrowseOrgSpecificAaTracks;

use strict;
use lib $ENV{GUS_HOME} . "/lib/perl";
use Data::Dumper;
use URI::Escape;
use Storable 'dclone';
use ApiCommonModel::Model::JBrowseTrackConfig::ProteinRefSeqTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::ProteinExpressionMassSpec;
use ApiCommonModel::Model::JBrowseTrackConfig::UnifiedPostTranslationalMod;
use ApiCommonModel::Model::JBrowseTrackConfig::SignalPeptideTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::TmhmmTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::LowComplexityTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::HydropathyTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::SecondaryStructureTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::InterproDomainsTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::ExportPredTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::IedbTrackConfig;

sub processOrganism {
  my ($organismAbbrev, $projectName, $buildNumber, $webservicesDir, $applicationType, $jbrowseUtil, $result) = @_;

  my $datasetProps = $jbrowseUtil->getDatasetProperties();
  #print Dumper ($datasetProps);
  ### Get organism properties
  my $orgHash = ($datasetProps->{'organism'});
  my $nameForFileName = ($orgHash->{organismNameForFiles});
  my $projectName = ($orgHash->{projectName});


#  &addProteinRefSeq($result, $datasetProps, $webservicesDir, $nameForFileName, $projectName, $applicationType, $buildNumber);
  &addInterproDomains($result, $datasetProps, $webservicesDir, $nameForFileName, $projectName, $applicationType, $buildNumber);
  &addSignalPeptide($result, $datasetProps, $webservicesDir, $nameForFileName, $projectName, $applicationType, $buildNumber);
  &addTmhmm($result, $datasetProps, $webservicesDir, $nameForFileName, $projectName, $applicationType, $buildNumber);
  &addLowComplexity($result, $datasetProps, $webservicesDir, $nameForFileName, $projectName, $applicationType, $buildNumber);
  &addHydropathy($result, $datasetProps, $webservicesDir, $nameForFileName, $projectName, $applicationType, $buildNumber);
  &addSecondaryStructureHelix($result, $datasetProps, $webservicesDir, $nameForFileName, $projectName, $applicationType, $buildNumber);
  &addSecondaryStructureCoil($result, $datasetProps, $webservicesDir, $nameForFileName, $projectName, $applicationType, $buildNumber);
  &addSecondaryStructureStrand($result, $datasetProps, $webservicesDir, $nameForFileName, $projectName, $applicationType, $buildNumber);
  &addExportPred($result, $datasetProps, $webservicesDir, $nameForFileName, $projectName, $applicationType, $buildNumber);
  &addIedb($result, $datasetProps, $webservicesDir, $nameForFileName, $projectName, $applicationType, $buildNumber);

  &addProteinExpressionMassSpec($result, $datasetProps, $webservicesDir, $nameForFileName, $projectName, $applicationType, $buildNumber);
}

sub addProteinRefSeq {
  my ($result, $datasetProperties, $webservicesDir, $nameForFileNames, $projectName, $applicationType, $buildNumber) = @_;

    my $refSeqTrack;
    my $relativePathToGffFile = "${webservicesDir}/UniDB/build-$buildNumber/${nameForFileNames}/genomeAndProteome/fasta/AnnotatedProteins.fasta";
#    my $relativePathToGffFile = "${webservicesDir}/PlasmoDB/build-68/Pfalciparum3D7/fasta/AnnotatedProteins.fasta";

    my $summary = "Individual amino acids are colored based on their<br>physical properties:</p><img src='/a/images/pbrowse_legend.png'  height='150' width='248' align=left/><p><table><tr><td>A - Alanine</td><td>C - Cysteine</td></tr><tr><td>D - Aspartic Acid&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td>E - Glutamic Acid</td></tr><tr><td>F - Phenyalanine</td><td>G - Glycine</td></tr><tr><td>H - Histidine</td><td>I - Isoleucine</td></tr><tr><td>K - Lysine</td><td>L - Leucine</td></tr><tr><td>M - Methionine</td><td>N - Asparagine</td></tr><tr><td>P - Proline</td><td>Q - Glutamine</td></tr><tr><td>R - Arginine</td><td>S - Serine</td></tr><tr><td>T - Threonine</td><td>V - Valine</td></tr><tr><td>W - Tryptophan</td><td>Y - Tyrosine</td></tr></table</p><br><b>Note:</b>The color palette for the amino acid reference<br>track can be changed by clicking on<br>Reference Sequence -> Edit config<br>and editing the proteinColorScheme to an<br>alternative palette.<br>Available palettes are:<br>buried<br>cinema<br>clustal<br>clustal2<br>helix<br>hydrophobicity<br>lesk<br>mae<br>purine<br>strand<br>taylor<br>turn<br>zappo<br><br>";

    my $queryParams = {
                            'seqType' => "protein",
                            'feature' => "ReferenceSequenceAa",
                                           };

    $refSeqTrack = ApiCommonModel::Model::JBrowseTrackConfig::ProteinRefSeqTrackConfig->new({
                                                                                                project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToGffFile,
                                                                                                application_type => $applicationType,
												summary => $summary,
                                                                                                key => "Reference Sequence",
                                                                                                label => "NA",
                                                                                                query_params => $queryParams,
                                                                                                })->getConfigurationObject();

   push @{$result->{tracks}}, $refSeqTrack if($refSeqTrack);
}


sub addInterproDomains {
  my ($result, $datasetProperties, $webservicesDir, $nameForFileNames, $projectName, $applicationType, $buildNumber) = @_;

    my $interproDomainsTrack;
    my $relativePathToGffFile = "${nameForFileNames}/genomeAndProteome/gff/iprscan_out.gff.gz";
    my $summary = "Interpro: PFam, PIR, Prints, Prodom, Smart, Superfamily, TIGRFAM, Prosite";

    my $queryParams = {
                            'seqType' => "protein",
                            'feature' => "domain:interpro",
                                           };

    $interproDomainsTrack = ApiCommonModel::Model::JBrowseTrackConfig::InterproDomainsTrackConfig->new({
                                                                                                project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToGffFile,
                                                                                                application_type => $applicationType,
                                                                                                summary => $summary,
                                                                                                key => "InterPro Domains",
                                                                                                label => "InterPro Domains",
                                                                                                query_params => $queryParams,
                                                                                                })->getConfigurationObject();

   push @{$result->{tracks}}, $interproDomainsTrack if($interproDomainsTrack);
}


sub addSignalPeptide {
  my ($result, $datasetProperties, $webservicesDir, $nameForFileNames, $projectName, $applicationType, $buildNumber) = @_;
    
    my $signalPeptideTrack;
    my $relativePathToGffFile = "${nameForFileNames}/genomeAndProteome/gff/signalP.gff.gz";
    my $summary = "Signal peptide predictions by SP-HMM/SP-NN";

    my $queryParams = {
                            'seqType' => "protein",
                            'feature' => "domain:SignalP",
                                           };

    $signalPeptideTrack = ApiCommonModel::Model::JBrowseTrackConfig::SignalPeptideTrackConfig->new({
                                                                                                project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToGffFile,
                                                                                                application_type => $applicationType,
												summary => $summary,
												key => "Signal Peptide",
												label => "Signal Peptide",
												query_params => $queryParams,
                                                                                                })->getConfigurationObject();

   push @{$result->{tracks}}, $signalPeptideTrack if($signalPeptideTrack);
}


sub addTmhmm {
  my ($result, $datasetProperties, $webservicesDir, $nameForFileNames, $projectName, $applicationType, $buildNumber) = @_;

    my $tmhmmTrack;
    my $relativePathToGffFile = "${nameForFileNames}/genomeAndProteome/gff/tmhmm.gff.gz";
    my $summary = "Transmembrane domains detected by TMHMM";

    my $queryParams = {
                            'seqType' => "protein",
                            'feature' => "domain:TMHMM",
                                           };

    $tmhmmTrack = ApiCommonModel::Model::JBrowseTrackConfig::TmhmmTrackConfig->new({
                                                                                                project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToGffFile,
                                                                                                application_type => $applicationType,
												summary => $summary,
												key => "Transmembrane Domains (TMHMM)",
                                                                                                label => "NA",
                                                                                                query_params => $queryParams,
                                                                                                })->getConfigurationObject();

   push @{$result->{tracks}}, $tmhmmTrack if($tmhmmTrack);
}


sub addLowComplexity {
  my ($result, $datasetProperties, $webservicesDir, $nameForFileNames, $projectName, $applicationType, $buildNumber) = @_;

    my $lowComplexityTrack;
    my $relativePathToBedFile = "${nameForFileNames}/genomeAndProteome/bed/proteinLowComplexity.bed.gz";
    my $summary = "Regions of low sequence complexity, as defined by the SEG algorithm of Wooton and Federhen. A description of the SEG algorithm can be found in Wootton, J.C. and Federhen, S. 1993 Statistics of local complexity in amino acid sequence and sequence database. Comput. Chem. 17149–163.";

    my $queryParams = {
                            'seqType' => "protein",
                            'feature' => "lowcomplexity:seg",
                                           };

    $lowComplexityTrack = ApiCommonModel::Model::JBrowseTrackConfig::LowComplexityTrackConfig->new({
                                                                                                project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToBedFile,
                                                                                                application_type => $applicationType,
                                                                                                summary => $summary,
                                                                                                key => "Low Complexity Regions",
                                                                                                label => "Low Complexity Regions",
                                                                                                query_params => $queryParams,
                                                                                                })->getConfigurationObject();

   push @{$result->{tracks}}, $lowComplexityTrack if($lowComplexityTrack);
}


sub addHydropathy {
  my ($result, $datasetProperties, $webservicesDir, $nameForFileNames, $projectName, $applicationType, $buildNumber) = @_;

    my $hydropathyTrack;
    my $relativePathToBigWigFile = "${nameForFileNames}/genomeAndProteome/bigwig/hydropathy.bw";
    my $summary = "Kyte-Doolittle hydropathy plot";

    my $queryParams = {
                            'seqType' => "protein",
                            'feature' => "hydropathy_jbrowse",
                                           };

    $hydropathyTrack = ApiCommonModel::Model::JBrowseTrackConfig::HydropathyTrackConfig->new({
                                                                                                project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToBigWigFile,
                                                                                                application_type => $applicationType,
                                                                                                summary => $summary,
                                                                                                key => "Kyte-Doolittle hydropathy plot",
                                                                                                label => "Kyte-Doolittle hydropathy plot",
                                                                                                query_params => $queryParams,
												pos_color => "orange",
                                                                                                })->getConfigurationObject();

   push @{$result->{tracks}}, $hydropathyTrack if($hydropathyTrack);
}


sub addSecondaryStructureHelix {
  my ($result, $datasetProperties, $webservicesDir, $nameForFileNames, $projectName, $applicationType, $buildNumber) = @_;

    my $secondaryStructureHelixTrack;
    my $relativePathToBigWigFile = "${nameForFileNames}/genomeAndProteome/bigwig/psipred_helix.bw";
    my $summary = "PSIPRED secondary structure prediction";

    my $queryParams = {
                            'seqType' => "protein",
                            'feature' => "get_2d_struc_jbrowse",
                                           };

    $secondaryStructureHelixTrack = ApiCommonModel::Model::JBrowseTrackConfig::SecondaryStructureTrackConfig->new({
                                                                                                project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToBigWigFile,
                                                                                                application_type => $applicationType,
                                                                                                summary => $summary,
                                                                                                key => "PSIPRED Helix",
                                                                                                label => "PSIPRED Helix",
                                                                                                query_params => $queryParams,
												pos_color => "red",
                                                                                                })->getConfigurationObject();

   push @{$result->{tracks}}, $secondaryStructureHelixTrack if($secondaryStructureHelixTrack);
}


sub addSecondaryStructureCoil {
  my ($result, $datasetProperties, $webservicesDir, $nameForFileNames, $projectName, $applicationType, $buildNumber) = @_;

    my $secondaryStructureCoilTrack;
    my $relativePathToBigWigFile = "${nameForFileNames}/genomeAndProteome/bigwig/psipred_coil.bw";
    my $summary = "PSIPRED secondary structure prediction";

    my $queryParams = {
                            'seqType' => "protein",
                            'feature' => "get_2d_struc_jbrowse",
                                           };

    $secondaryStructureCoilTrack = ApiCommonModel::Model::JBrowseTrackConfig::SecondaryStructureTrackConfig->new({
                                                                                                project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToBigWigFile,
                                                                                                application_type => $applicationType,
                                                                                                summary => $summary,
                                                                                                key => "PSIPRED Coil",
                                                                                                label => "PSIPRED Coil",
                                                                                                query_params => $queryParams,
												pos_color => "green",
                                                                                                })->getConfigurationObject();

   push @{$result->{tracks}}, $secondaryStructureCoilTrack if($secondaryStructureCoilTrack);
}


sub addSecondaryStructureStrand {
  my ($result, $datasetProperties, $webservicesDir, $nameForFileNames, $projectName, $applicationType, $buildNumber) = @_;

    my $secondaryStructureStrandTrack;
    my $relativePathToBigWigFile = "${nameForFileNames}/genomeAndProteome/bigwig/psipred_extended.bw";
    my $summary = "PSIPRED secondary structure prediction";

    my $queryParams = {
                            'seqType' => "protein",
                            'feature' => "get_2d_struc_jbrowse",
                                           };

    $secondaryStructureStrandTrack = ApiCommonModel::Model::JBrowseTrackConfig::SecondaryStructureTrackConfig->new({
                                                                                                project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToBigWigFile,
                                                                                                application_type => $applicationType,
                                                                                                summary => $summary,
                                                                                                key => "PSIPRED Strand",
                                                                                                label => "PSIPRED Strand",
                                                                                                query_params => $queryParams,
												pos_color => "blue",
                                                                                                })->getConfigurationObject();

   push @{$result->{tracks}}, $secondaryStructureStrandTrack if($secondaryStructureStrandTrack);
}


sub addExportPred {
  my ($result, $datasetProperties, $webservicesDir, $nameForFileNames, $projectName, $applicationType, $buildNumber) = @_;

    my $exportPredTrack;
    my $relativePathToGffFile = "${nameForFileNames}/genomeAndProteome/gff/exportpred.gff.gz";
    my $summary = "Export domains predicted by ExportPred";

    my $queryParams = {
                            'seqType' => "protein",
                            'feature' => "domain:ExportPred",
                                           };

    $exportPredTrack = ApiCommonModel::Model::JBrowseTrackConfig::ExportPredTrackConfig->new({
                                                                                                project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToGffFile,
                                                                                                application_type => $applicationType,
                                                                                                summary => $summary,
                                                                                                key => "Predicted Protein Export Domains",
                                                                                                label => "NA",
                                                                                                query_params => $queryParams,
                                                                                                })->getConfigurationObject();

   push @{$result->{tracks}}, $exportPredTrack if($exportPredTrack);
}

sub addIedb {
    my ($result, $datasetProperties, $webservicesDir, $nameForFileNames, $projectName, $applicationType, $buildNumber) = @_;

    my $iedbTrack;
    my $relativePathToGffFile = "${nameForFileNames}/genomeAndProteome/gff/iedb.gff.gz";
    my $summary = "Immune Epitope Database (IEDB) predictions";

    my $queryParams = {
                           'seqType' => "protein",
                           'feature' => "domain:IEDB",
                                           };

    $iedbTrack = ApiCommonModel::Model::JBrowseTrackConfig::IedbTrackConfig->new({
                                                                                                project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToGffFile,
                                                                                                application_type => $applicationType,
                                                                                                summary => $summary,
                                                                                                key => "IEDB predictions",
                                                                                                label => "IEDB predictions",
                                                                                                query_params => $queryParams,
                                                                                                })->getConfigurationObject();

   push @{$result->{tracks}}, $iedbTrack if($iedbTrack);
}

sub addProteinExpressionMassSpec {
  my ($result, $datasetProps, $webservicesDir, $nameForFileNames, $projectName, $applicationType, $buildNumber) = @_;


  my $hasPTMDataset;

  my $proteinExpressionMassSpecDatasets = $datasetProps->{protexpmassspec} ? $datasetProps->{protexpmassspec} : {};

  foreach my $dataset (keys %$proteinExpressionMassSpecDatasets) {
    next unless($dataset =~ /_massSpec_/);

    my $experimentName = $proteinExpressionMassSpecDatasets->{$dataset}->{name};
    my $datasetDisplayName = $proteinExpressionMassSpecDatasets->{$dataset}->{datasetDisplayName};
    my $datasetPresenterId = $proteinExpressionMassSpecDatasets->{$dataset}->{datasetPresenterId};
    my $datasetExtdbName = $proteinExpressionMassSpecDatasets->{$dataset}->{datasetExtdbName};
    my $category = $proteinExpressionMassSpecDatasets->{$dataset}->{datasetClassCategory};

    my $hasPTMs = $proteinExpressionMassSpecDatasets->{$dataset}->{hasPTMs};

    my $summary = $proteinExpressionMassSpecDatasets->{$dataset}->{summary};
    $summary =~ s/\n/ /g;
    my $shortAttribution = $proteinExpressionMassSpecDatasets->{$dataset}->{shortAttribution};

    my $feature = "domain:MassSpecPeptide";

    if(lc($hasPTMs) eq 'true') {
      $feature = "domain:MassSpecPeptidePhospho";
      $hasPTMDataset = 1;
    }

    my $relativePathToGffFile = "${nameForFileNames}/massSpec/gff/${datasetExtdbName}/ms_peptides_protein_align.gff.gz";

    my $massSpec = ApiCommonModel::Model::JBrowseTrackConfig::ProteinExpressionMassSpec->new({  
                                                                                                project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToGffFile,
                                                                                                key => "${datasetDisplayName}  MS/MS Peptides  $shortAttribution",
                                                                                                label => "${dataset}",
                                                                                                dataset_name => $dataset,
                                                                                                attribution => $shortAttribution,
                                                                                                study_display_name => $datasetDisplayName,
                                                                                                summary => $summary,
                                                                                                application_type => $applicationType,
                                                                                                dataset_presenter_id => $datasetPresenterId,
												glyph => "JBrowse/View/FeatureGlyph/Box",
                                                                                              })->getConfigurationObject();

    push @{$result->{tracks}}, $massSpec if($massSpec);
  }

  if($hasPTMDataset) {

  my $unifiedPtm = ApiCommonModel::Model::JBrowseTrackConfig::UnifiedPostTranslationalMod->new({application_type => $applicationType,

                                                                                              })->getConfigurationObject();

    push @{$result->{tracks}}, $unifiedPtm if($unifiedPtm);
  }

}

1;
