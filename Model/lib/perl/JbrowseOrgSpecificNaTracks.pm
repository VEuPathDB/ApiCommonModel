package ApiCommonModel::Model::JbrowseOrgSpecificNaTracks;

use strict;
use lib $ENV{GUS_HOME} . "/lib/perl";
use JSON;

use ApiCommonModel::Model::JBrowseTrackConfig::UnifiedMassSpecTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::UnifiedSnpTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::ScaffoldsTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::CentromereTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::TrnaTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::NrdbProteinTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::VCFStore;
use ApiCommonModel::Model::JBrowseTrackConfig::AlignmentsTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::ChipChipSmoothedTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::BigWigStore;
use ApiCommonModel::Model::JBrowseTrackConfig::ChipChipPeakTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::CnvArrayTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::ProteinExpressionMassSpec;
use ApiCommonModel::Model::JBrowseTrackConfig::SmallNcRnaSeq;
use ApiCommonModel::Model::JBrowseTrackConfig::ApolloGffTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::VcfTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::SyntenyTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::LongReadRNASeqTrackConfig;
use ApiCommonModel::Model::JBrowseTrackConfig::AntiSmashTrackConfig;

use Data::Dumper;

use URI::Escape;
use Storable 'dclone';
use Tie::IxHash;

sub processOrganism {
  my ($organismAbbrev, $projectName, $isApollo, $buildNumber, $webservicesDir, $applicationType, $jbrowseUtil, $result) = @_;

  my %datasets;
  my $t = tie %datasets, 'Tie::IxHash';
  my %strain;

  my $datasetProps = $jbrowseUtil->getDatasetProperties();

  my $dbh = $jbrowseUtil->getDbh();

  ### Get organism properties
  my $orgHash = ($datasetProps->{'organism'});
  my $nameForFileNames = ($orgHash->{organismNameForFiles});
  my $projectName = ($orgHash->{projectName});
  my $isAnnotated = ($orgHash->{isAnnotatedGenome});
  my $isReference = ($orgHash->{isReferenceStrain});

  &addScaffolds($datasetProps, $applicationType, $result);
  &addCentromere($datasetProps, $applicationType, $result);
  &addUnifiedMassSpec($datasetProps, $applicationType, $result);
  &addUnifiedSnp($datasetProps, $applicationType, $result);

  &addSynteny($applicationType, $dbh, $result);

  &addDatasets($dbh, \%datasets, \%strain) unless($isApollo);

  # TODO: get these from buildProps
  my $datasetProperties = $datasetProps;

  &addSynteny($applicationType, $dbh, $result, $organismAbbrev);
  &addDatasets($dbh, \%datasets, \%strain) unless($isApollo);
  &addChipChipTracks($dbh, $result, $datasetProperties, $organismAbbrev, $applicationType);
  &addSmallNcRnaSeq($datasetProperties, $projectName, $buildNumber, $nameForFileNames, $applicationType, $result);

  &addProteinExpressionMassSpec($datasetProperties, $applicationType, $result);
  &addVCF($dbh, $result, $datasetProperties, $nameForFileNames, $organismAbbrev, $projectName, $buildNumber, $applicationType);
  #&addGFF($dbh, $result, $datasetProperties);

  &addTRNA($datasetProps, $result, $applicationType);
  if ($projectName !~ m/HostDB/ && $organismAbbrev !~ m/cgloCBS148.51/ && $organismAbbrev !~ m/pgig/ && $organismAbbrev !~ m/amutUAMH3576/ && $organismAbbrev !~ m/anigUAMH3544/ && $organismAbbrev !~ m/bcerUAMH5669/){
      &addNrdbProteinAlignments($result, $datasetProperties, $nameForFileNames, $organismAbbrev, $projectName, $buildNumber, $applicationType, $datasetProperties, $webservicesDir);
  }

  if ($organismAbbrev !~ m/dmeliso-1/ ){
      &addApolloGFF($dbh, $result, $organismAbbrev, $applicationType);
  }

  &addMergedRnaSeq($dbh, $result, $datasetProperties, $projectName, $nameForFileNames, $organismAbbrev, $buildNumber);

  &addLongReadRNASeq($result, $datasetProperties, $nameForFileNames, $webservicesDir, $projectName, $buildNumber, $applicationType);


  # TODO:  need to set isReference 
  if($projectName eq 'FungiDB' && $isReference) {
      &addAntismash($result, $nameForFileNames, $webservicesDir, $projectName, $applicationType);
  }


  # other organism specific tracks
  if($organismAbbrev eq 'tcruCLBrenerEsmeraldo-like') {
      &addCnvArray($dbh, $result, $projectName, $applicationType);
  }
  # TODO: Add back
  #if ($isAnnotated eq 'true'){
  #    &addAnnotatedGenome($dbh, $result, $datasetProperties);
  #}
  #&addFastaAssemblyTrack($dbh, $result, $datasetProperties);

  unless($isApollo) {
      $result->{datasets} = \%datasets;
      $result->{dataset_id} = $organismAbbrev;

      # $organismAbbrev is internal_abbrev here; if not same as public_abbrev
      # then the dataset_id needs be set to public_abbrev
      if ($strain{$organismAbbrev}->{public} ne $organismAbbrev) {
	  $result->{dataset_id} = $strain{$organismAbbrev}->{public};
      }
  }

  my $orgPublicAbbrev = $strain{$organismAbbrev}->{public};

  &addGenes($result, $orgPublicAbbrev, $projectName, $nameForFileNames);
}

sub addDatasets {
  my ($dbh, $datasets, $strain) = @_;
  #Public facing track requires public_abbrev here!
  my $sql = "select public_abbrev, internal_abbrev, organism_name FROM Apidbtuning.organismattributes order by organism_name";

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($abbrev, $internalAbbrev, $name) = $sh->fetchrow_array()) {
    $datasets->{$abbrev}->{name} = $name;
    $datasets->{$abbrev}->{url} = "?data=/a/service/jbrowse/tracks/${abbrev}";
    $strain->{$internalAbbrev}->{public} = $abbrev;
  }
  $sh->finish();
}


sub addVCF {
  my ($dbh, $result, $datasetProperties, $nameForFileNames, $organismAbbrev, $projectName, $buildNumber, $applicationType) = @_;

  my $vcfDatasets = $datasetProperties->{vcffile} ? $datasetProperties->{vcffile} : {};

  foreach my $dataset (keys %$vcfDatasets) {
    next unless($dataset =~ /VCF/);
    my $experimentName = $dataset =~ m/${organismAbbrev}_(.+)_ebi_VCF_RSRC/;
    my $datasetDisplayName = $vcfDatasets->{$dataset}->{datasetDisplayName};
    my $summary = $vcfDatasets->{$dataset}->{summary};
    
    $summary =~ s/\n/ /g;
    my $shortAttribution = $datasetProperties->{$dataset}->{shortAttribution};

      my $sampleName = $vcfDatasets->{$dataset}->{datasetName};
      my ($vcfFileName) = $sampleName =~ m/${organismAbbrev}_(.+)_ebi_VCF_RSRC/;
      my $keyName = $vcfFileName;
 	  $keyName =~ s/_/ /g;
	  $keyName =~ s/\./ /g;
      #my $vcfUrl = "/a/service/jbrowse/store?data=" . uri_escape_utf8("${nameForFileNames}/vcf/${sampleName}/${vcfFileName}.vcf.gz");
      my $relativePathToVcfFile = "${nameForFileNames}/vcf/${sampleName}/${vcfFileName}.vcf.gz";
      my $alignment = ApiCommonModel::Model::JBrowseTrackConfig::VcfTrackConfig->new({
												project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToVcfFile,
												dataset_name  => $dataset,
												study_display_name => $datasetDisplayName,
												description => $summary,
                                                                                                key => "$keyName SNPs from VCF",
                                                                                                label => "${sampleName} SNPs",
                                                                                                application_type => $applicationType,
                                                                                                attribution => $shortAttribution,
                                                                                                summary => $summary,
                                                                                              })->getConfigurationObject();

      push @{$result->{tracks}}, $alignment;
  }
}

sub addApolloGFF {
    my ($dbh, $result, $organismAbbrev, $applicationType) = @_;

  my $sql = "select count(*) from apidbtuning.ApolloId aid, apidbtuning.organismattributes oa where (oa.public_abbrev='".$organismAbbrev."' OR oa.internal_abbrev='".$organismAbbrev."') and aid.organism = oa.organism_name";

  my $sh = $dbh->prepare($sql);
  $sh->execute();
  my $count = $sh->fetchrow_array();
  $sh->finish();
  if($count > 0) {

    my $apolloDescription = "Community annotation represents user provided effort to improve the current gene models and offer alternatives based on -omic level evidence. Users can utilise our Apollo instance for creating and editing functional annotation to be displayed in this track. Only when the status of the gene model is changed to 'Finished' will the model be displayed, normally within 24 hours of the status change.";

    my $track = ApiCommonModel::Model::JBrowseTrackConfig::ApolloGffTrackConfig->new({
                                                                                                application_type => $applicationType,
												summary => $apolloDescription,
                                                                                              })->getConfigurationObject();
    push @{$result->{tracks}}, $track;
  }
}

sub addMergedRnaSeq {
  my ($dbh, $result, $datasetProperties, $projectName, $nameForFileNames, $organismAbbrev, $buildNumber) = @_;
  my @urlArray;
  my $genomeName;

  my $rnaSeqDatasets = $datasetProperties->{rnaseq} ? $datasetProperties->{rnaseq} : {};
  foreach my $dataset (keys %$rnaSeqDatasets) {
    next unless($dataset =~ /rnaSeq/);

    my @urlArrayProject;
    my $experimentName = $dataset =~ m/${organismAbbrev}_(.+)_ebi_rnaSeq_RSRC/;
    my $datasetDisplayName = $rnaSeqDatasets->{$dataset}->{datasetDisplayName};
    my $summary = $rnaSeqDatasets->{$dataset}->{summary};
    $summary =~ s/\n/ /g;
    my $shortAttribution = $rnaSeqDatasets->{$dataset}->{shortAttribution};
    my $keyName = $datasetDisplayName;
    
    $genomeName = ${nameForFileNames};
      #my ($sampleName) = $sampleDataset;
      my ($sampleName) = $dataset;
      my ($bigwigFileName) = $sampleName =~ m/${organismAbbrev}_(.+)_ebi_rnaSeq_RSRC/;
      my $keyName = $bigwigFileName;
         $keyName =~ s/_/ /g;

        my $bigWigRelativePath = "/var/www/Common/apiSiteFilesMirror/webServices/${projectName}/build-${buildNumber}/${nameForFileNames}/bigwig/${sampleName}/mergedBigwigs/*";
        my @bigwigFiles = glob($bigWigRelativePath);
        my $shortAttribution = $rnaSeqDatasets->{$dataset}->{shortAttribution};
        foreach(@bigwigFiles){
                my $bigwigPath = $_;
                my $bigwigName = (split '/', $bigwigPath)[-1];
                my $shortBigwigName = $bigwigName;
                my $shortBigwigName = substr($shortBigwigName,0, -3);
                my $bigwigUrl = "/a/service/jbrowse/store?data=" . uri_escape_utf8("${nameForFileNames}/bigwig/${sampleName}/mergedBigwigs/${bigwigName}");
                my $template = { url=>${bigwigUrl}, name=> ${shortBigwigName}, color=> 'black' };
                push (@urlArray, $template);
                push (@urlArrayProject, $template);
                }
 }
        ### Print out combinedRNAseq track for organism
        my $arrayLength = @urlArray;

    if ($arrayLength > 0){
        my $alignment = {storeClass => "MultiBigWig/Store/SeqFeature/MultiBigWig",
        urlTemplates => \@urlArray,
        showTooltips => "true",
        key => "${genomeName} combined RNAseq plot",
        label => "${genomeName} combined RNAseq plot",
        type  => "MultiBigWig/View/Track/MultiWiggle/MultiXYPlot",
        category => "Transcriptomics",
        autoscale => "local",
        yScalePosition => "left",
        style => {'height' => "40",
        },
                  metadata => {
                    subcategory => "RNA-Seq",
                    dataset => "Combined all RNA-Seq data for ${genomeName}",
                    trackType => "Multi XY plot",
                    alignment => "Unique", 
                   },
      };
      push @{$result->{tracks}}, $alignment;
  }
}


sub addProteinExpressionMassSpec {

  my ($datasetProperties, $applicationType, $result) = @_;
  my $proteinExpressionMassSpecDatasets = $datasetProperties->{protexpmassspec} ? $datasetProperties->{protexpmassspec} : {};

  foreach my $dataset (keys %$proteinExpressionMassSpecDatasets) {
    next unless($dataset =~ /_massSpec_/);

    my $experimentName = $proteinExpressionMassSpecDatasets->{$dataset}->{name};
    my $datasetDisplayName = $proteinExpressionMassSpecDatasets->{$dataset}->{datasetDisplayName};
    my $datasetPresenterId = $proteinExpressionMassSpecDatasets->{$dataset}->{presenterId};
    my $category = $proteinExpressionMassSpecDatasets->{$dataset}->{datasetClassCategory};

    my $datasetExtdbName = $proteinExpressionMassSpecDatasets->{$dataset}->{datasetExtdbName};

    my $summary = $proteinExpressionMassSpecDatasets->{$dataset}->{summary};
    $summary =~ s/\n/ /g;
    my $shortAttribution = $proteinExpressionMassSpecDatasets->{$dataset}->{shortAttribution};

    # TODO - no need to remove "()" around attribution
    $shortAttribution =~s/\((.*)\)/$1/;

my $queryParams = {
                            'edName' => "like '${datasetExtdbName}'",
                            'feature' => "domain:MassSpecPeptide",
                                           };
    my $massSpec = ApiCommonModel::Model::JBrowseTrackConfig::ProteinExpressionMassSpec->new({
                                                                                                key => "${datasetDisplayName}  MS/MS Peptides  $shortAttribution",
                                                                                                label => "${dataset}",
                                                                                                dataset_name => $dataset,
                                                                                                attribution => $shortAttribution,
                                                                                                study_display_name => $datasetDisplayName,
                                                                                                summary => $summary,
                                                                                                application_type => $applicationType,
                                                                                                query_params => $queryParams,
                                                                                                dataset_presenter_id => $datasetPresenterId,
                                                                                              })->getConfigurationObject();

    push @{$result->{tracks}}, $massSpec;
  }
}

sub addSmallNcRnaSeq {
  my($datasetProperties, $projectName, $buildNumber, $nameForFileNames, $applicationType, $result) = @_;

   my $smallNcRnaSeqDatasets = $datasetProperties->{smallncrnaseq} ? $datasetProperties->{smallncrnaseq} : {};
   foreach my $dataset (keys %$smallNcRnaSeqDatasets){

    next unless($dataset =~ /smallNcRna/);

    my $experimentName = $smallNcRnaSeqDatasets->{$dataset}->{experimentName};
    my $datasetDisplayName = $smallNcRnaSeqDatasets->{$dataset}->{datasetDisplayName};
    my $summary = $smallNcRnaSeqDatasets->{$dataset}->{summary};
    $summary =~ s/\n/ /g;
    my $shortAttribution = $smallNcRnaSeqDatasets->{$dataset}->{shortAttribution};

    # This is incorrect:
    # my ($sampleName) = $dataset =~ /${organismAbbrev}_${experimentName}_(.+)_smallNcRnaSample_RSRC/;

    my $sampleName = $experimentName;  # e.g: Gregory_ME49_ncRNA
    $sampleName =~s/.*_(.*)_ncRNA/$1/; # ME49


    # Example: EhistolyticaHM1IMSS/bam/Singh_Small_RNA/Rahman/Rahman.bam
    #my $bamUrl = "/a/service/jbrowse/store?data=" . uri_escape_utf8("${nameForFileNames}/bam/$experimentName/${sampleName}/${sampleName}.bam");
    my $relativePathToBamFile = "${nameForFileNames}/bam/$experimentName/${sampleName}/${sampleName}.bam";

    my $alignment = ApiCommonModel::Model::JBrowseTrackConfig::SmallNcRnaSeq->new({
                                                                                                project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToBamFile,
												dataset_name => $dataset,
                                                                                                attribution => $shortAttribution,
                                                                                                study_display_name => $datasetDisplayName,
                                                                                                description => $summary,
                                                                                                application_type => $applicationType,
                                                                                                summary => $summary,
                                                                                                #url_template => $bamUrl,
                                                                                                label => "$sampleName Small Non-coding RNAs",
                                                                                                key => "$sampleName Small Non-coding RNAs",
                                                                                              })->getConfigurationObject();
      push @{$result->{tracks}}, $alignment;
  }
}


sub addCentromere {
  my ($datasetProps, $applicationType, $result) = @_;
     my $hasCentromere = $datasetProps->{hasCentromere} ? $datasetProps->{hasCentromere} : {};
	if($hasCentromere == 1) {
     my $track = ApiCommonModel::Model::JBrowseTrackConfig::CentromereTrackConfig->new({application_type => $applicationType})->getConfigurationObject();
     push @{$result->{tracks}}, $track;
    };
}


sub addScaffolds {
  my ($datasetProps, $applicationType, $result) = @_;
     my $hasScaffold = $datasetProps->{hasScaffold} ? $datasetProps->{hasScaffold} : {};
        if($hasScaffold == 1) {
      my $track = ApiCommonModel::Model::JBrowseTrackConfig::ScaffoldsTrackConfig->new({application_type => $applicationType})->getConfigurationObject();
      push @{$result->{tracks}}, $track;
  }
}

sub addGenes {
  my ($result, $orgPublicAbbrev, $projectName, $nameForFileNames) = @_;

  my $urlTemplate = "/a/service/jbrowse/store?data=" . $nameForFileNames . "/gff/annotated_transcripts.gff.gz";
  my $track = {
	       storeClass => "JBrowse/Store/SeqFeature/GFF3Tabix",
	       key => "Annotated Transcripts (UTRs in White when available)",
	       label => "gene",
	       type  => "NeatCanvasFeatures/View/Track/NeatFeatures",
	       category => "Gene Models",
	       unsafePopup => JSON::true,
	       glyph => "NeatCanvasFeatures/View/FeatureGlyph/Gene",
	       urlTemplate => $urlTemplate,
	       maxheight => 4000,
	       style => {
                         label => "id",
                         description => "note, description",
                         showLabels => JSON::true,
			 color => "{processedTranscriptColor}",
			 borderColor=> "{processedTranscriptBorderColor}",
			 unprocessedTranscriptColor=> "{unprocessedTranscriptColor}",
                         topLevelFeaturesPercent => 10,
                         labelScale=> 0.01},
	       metadata => {
			    subcategory => "Transcripts",
			    trackType => "Processed Transcript"
			   },
 	       onClick => {
 			   content => "function(track, feature) { track.project ='$projectName'; track.orgabbrev='$orgPublicAbbrev'; return track.browser.config.geneDetailsNew(track, feature)}"
 			  },
   	       menuTemplate => [
  				{
				 title=> "{id} details",
				 content => "function(track, feature) { track.project ='$projectName'; track.orgabbrev='$orgPublicAbbrev'; return track.browser.config.geneDetailsNew(track, feature)}",
				},
				{
				 label=> "View Gene Page",
				 iconClass => "dijitIconDatabase",
				 action => "newWindow",
				 url => "function(track,f) { return '/a/app/record/gene/' + f.get('id') }"
				}
 			       ]
	      };
  push (@{$result->{tracks}}, $track);
}


sub addSynteny {
  my ($applicationType, $dbh, $result, $organismAbbrev) = @_;

  return unless ($applicationType eq 'jbrowse' );
  # Requires public_abbrev here!
  my $sql = "select otr.organism, oa.internal_abbrev as public_abbrev, otr.phylum, otr.genus, otr.species, otr.kingdom, otr.class, gt.gtracks
            from APIDBTUNING.ORGANISMSELECTTAXONRANK otr
               , APIDBTUNING.ORGANISMATTRIBUTES oa
               RIGHT JOIN (select * from APIDBTUNING.GBROWSETRACKSORGANISM where type = 'synteny' ) gt
                ON oa.ORGANISM_NAME = gt.organism
            where oa.ORGANISM_NAME = otr.organism 
            and oa.IS_ANNOTATED_GENOME = 1
            and oa.PROJECT_ID in (select distinct name from core.projectinfo)";

  my $hasSyntenyTracks = 0;

  my $orgGTracks;
  my %subtracks;
  my %defaults;

  my $taxonNamesToNode = {};
  my $rootNode = _Tree->new({_name => 'root'});
  my $refOrganism;


  my $sh = $dbh->prepare($sql);
  $sh->execute();
  while(my ($organism, $publicAbbrev, $phylum, $genus, $species, $kingdom, $class, $gTracks) = $sh->fetchrow_array()) {
    if($publicAbbrev eq $organismAbbrev) {
      $hasSyntenyTracks = 1;
      $gTracks =~ s/^.+Synteny\///;
      %defaults = map { $_ => 1 } split(/\+/, $gTracks);
      $refOrganism = $organism;
    }
    my $kingdomNode = &makeTreeNode('k_' . $rootNode, $kingdom, $taxonNamesToNode, $rootNode);
    my $phylumNode = &makeTreeNode('p_' . $kingdom, $phylum, $taxonNamesToNode, $kingdomNode);
    my $classNode = &makeTreeNode('c_'. $phylum, $class, $taxonNamesToNode, $phylumNode);
    my $genusNode = &makeTreeNode('g_'. $class, $genus, $taxonNamesToNode, $classNode);
    my $speciesNode = &makeTreeNode('s_'. $genus, $species, $taxonNamesToNode, $genusNode);
    my $strainNode = &makeTreeNode('', $organism, $taxonNamesToNode, $speciesNode);

    # stuff these things in the leaf nodes
    $strainNode->setAbbrev($publicAbbrev);
    $strainNode->setFeatureFilters({ "taxon" => $organism});
    $strainNode->setMetadata({"Kingdom" => $kingdom,
                              "Phylum" => $phylum,
                              "Class" => $class,
                              "Genus" => $genus,
                              "Species" => $species 
                             });
  }
  $sh->finish();

  if($hasSyntenyTracks) {
    my $subtracksAr = [];

    my $refOrganismNode = $taxonNamesToNode->{$refOrganism};

    &addSubtracks($subtracksAr, $refOrganismNode, $taxonNamesToNode, \%defaults, $organismAbbrev);

    my $syntenyTrack = {storeClass => "EbrcTracks/Store/SeqFeature/REST",
                        baseUrl => "/a/service/jbrowse",
                        type => "EbrcTracks/View/Track/Synteny",
                        transcriptType => "processed_transcript",
                        noncodingType => ["nc_transcript"],
                        glyph => "function(f){return f.get('syntype') === 'span' ? 'JBrowse/View/FeatureGlyph/Box' : 'JBrowse/View/FeatureGlyph/Gene'; }",
                        subParts => "CDS,UTR,five_prime_UTR,three_prime_UTR,nc_exon,pseudogenic_exon",
                        key => "Syntenic Sequences and Genes (Shaded by Orthology)",
                        label => "Syntenic Sequences and Genes (Shaded by Orthology)",
                        region_feature_densities => "function(){return false}",
                        category => "Comparative Genomics",
			unsafePopup => JSON::true,
                        geneGroupAttributeName => "orthomcl_name",
                        displayMode => "normal",

                        style => {
                          color => "{syntenyColorFxn}",
                          unprocessedTranscriptColor => "lightgrey",
                          utrColor => "grey",
#                          borderWidth => 4,
                          connectorThickness => "function(f){return f.get('syntype') === 'span' ? 3 : 1; }",
                          showLabels => "function(){return false}",
                          strandArrow => "function(f){return f.get('syntype') === 'span' ? false : true; }",
                          height => "function(f){return f.get('syntype') === 'span' ? 2 : 5; }",
#                          height => 5,
                          marginBottom => 0,
                       },
                        metadata => {
                          subcategory => "Orthology and Synteny",
                          trackType => 'Segments',
                        },
                        query => {'feature' => "gene:syntenyJBrowseScaled"
                        },
                        subtracks => $subtracksAr,
                        onClick => {
                          content => "{syntenyTitleFxn}",
                        },
                        menuTemplate => [
                          {label => "View Details", 
                           content => "{syntenyTitleFxn}",
                          },
                          {label => "View Gene or Sequence Page",
                           title => "function(track,f) { return f.get('syntype') == 'span' ? f.get('contig') : f.get('name'); }", 
                           iconClass => "dijitIconDatabase", 
                           action => "iframeDialog", 
                           url => "function(track,f) { return f.get('syntype') == 'span' ? '/a/app/record/genomic-sequence/' + f.get('contig') : '/a/app/record/gene/' + f.get('name') }"}
                            ],
    };

#       my $syntenyTrack = ApiCommonModel::Model::JBrowseTrackConfig::SyntenyTrackConfig->new({
# 												application_type => $applicationType,
#                                                                                                 key => "Syntenic Sequences and Genes (Shaded by Orthology)",
#                                                                                                 label => "Syntenic Sequences and Genes (Shaded by Orthology)",
#                                                                                                 subTracks => $subtracksAr,
#                                                                                               })->getConfigurationObject();

    push @{$result->{tracks}}, $syntenyTrack;


  }
}


sub addSubtracks {
  my ($subtracks, $node, $taxonNamesToNode, $defaults, $organismAbbrev) = @_;

  return if($node->getAlreadySeen());
  return if($node->isRoot());

  if($node->isLeaf()) {
    my $abbrev = $node->getAbbrev();

    foreach my $type ("gene", "span") {
      my $metadataClone = dclone $node->getMetadata();
      my $ffClone = dclone $node->getFeatureFilters();
      $ffClone->{syntype} = $type;

      my $label = "${abbrev}_${type}";

      my $visible = $abbrev eq $organismAbbrev || $defaults->{$label} ? 'true' : 'false';

      my $subtrack = {featureFilters => $ffClone,
                      metadata => $metadataClone,
                      label => "$abbrev $type",
                      visible => $visible
      };
      push @$subtracks, $subtrack;
    }
  }
  else {
    my $children = $node->getChildren();

    foreach my $child (@$children) {
      &addSubtracks($subtracks, $child, $taxonNamesToNode, $defaults, $organismAbbrev);
    }
  }

  $node->setAlreadySeen(1);

  my $parent = $node->getParent();
  
  &addSubtracks($subtracks, $parent, $taxonNamesToNode, $defaults, $organismAbbrev);
}


sub makeTreeNode {
  my ($prefix, $name, $taxonNamesToNode, $parentNode) = @_;

  my $key = $prefix . $name;

  my $node = $taxonNamesToNode->{$key};
  unless($node) {
    $node = _Tree->new({_parent => $parentNode, _name => $name});
    $parentNode->addChild($node);
  }
  
  $taxonNamesToNode->{$key} = $node;

  return $node;
}


sub addUnifiedSnp {
  my ($datasetProps, $applicationType, $result) = @_;
    my $hasSnp = $datasetProps->{hasSnp} ? $datasetProps->{hasSnp} : {};
        if($hasSnp == 1) {
#    my $projectUrl = lc($projectName) . "\.org";

    my $snpTrack = ApiCommonModel::Model::JBrowseTrackConfig::UnifiedSnpTrackConfig->new({application_type => $applicationType,
											  #project_url => $projectUrl,
											  })->getConfigurationObject();
		
    push @{$result->{tracks}}, $snpTrack;
  };
}


sub addUnifiedMassSpec {
  my ($datasetProps, $applicationType, $result) = @_;
    my $hasMassSpec = $datasetProps->{hasMassSpec} ? $datasetProps->{hasMassSpec} : {};
        if($hasMassSpec == 1) {
    my $unifiedMassSpecTrack = ApiCommonModel::Model::JBrowseTrackConfig::UnifiedMassSpecTrackConfig->new({application_type => $applicationType })->getConfigurationObject();

    push @{$result->{tracks}}, $unifiedMassSpecTrack;
   };
}


sub addChipChipTracks {
  my ($dbh, $result, $datasetProperties, $organismAbbrev, $applicationType) = @_;

  my $chipChipSeqDatasets = $datasetProperties->{chipchip} ? $datasetProperties->{chipchip} : {};

 my $sql = "select d.name, s.name, pan.name, pan.protocol_app_node_id
from study.study s
   , SRES.EXTERNALDATABASERELEASE r
   , SRES.EXTERNALDATABASE d
   , study.protocolappnode pan
   , study.studylink sl
where d.name like '${organismAbbrev}%_chipChipExper_%'
and s.EXTERNAL_DATABASE_RELEASE_ID = r.EXTERNAL_DATABASE_RELEASE_ID
and r.EXTERNAL_DATABASE_ID = d.EXTERNAL_DATABASE_ID
and s.study_id = sl.study_id
and sl.protocol_app_node_id = pan.PROTOCOL_APP_NODE_ID
and s.investigation_id is null";


  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($dataset, $study, $panName, $panId) = $sh->fetchrow_array()) {

    if($panName =~ /_peaks \(ChIP-chip\)/) {
        my $peakTrack = &makeChipChipPeak($dataset, $study, $panName, $panId, $datasetProperties, $chipChipSeqDatasets, $applicationType);
        push @{$result->{tracks}}, $peakTrack;
    }
    if($panName =~ /_smoothed \(ChIP-chip\)/) {
      my $track = &makeChipChipSmoothed($dataset, $study, $panName, $panId, $datasetProperties, $chipChipSeqDatasets, $applicationType);
      push @{$result->{tracks}}, $track;
    }
  }
 
  $sh->finish();
}


sub makeChipChipPeak {
  my ($dataset, $study, $panName, $panId, $datasetProperties, $chipChipSeqDatasets, $applicationType) = @_;

    my $datasetDisplayName = $chipChipSeqDatasets->{$dataset}->{datasetDisplayName};
    my $summary = $chipChipSeqDatasets->{$dataset}->{summary};
    $summary =~ s/\n/ /g;
    my $shortAttribution = $chipChipSeqDatasets->{$dataset}->{shortAttribution};
    my $datasetPresenterId = $chipChipSeqDatasets->{$dataset}->{presenterId};

  my $key = $panName;
  my $subTrackAttr = $chipChipSeqDatasets->{$dataset}->{subTrackAttr};
  my $cutoff = $datasetProperties->{$dataset}->{cutoff} || 0;
  my $colorFunction = $cutoff ? "colorSegmentByScore" : "chipColor";

  my $queryParams = {
                            'exp' => $dataset,
                            'sub' => $subTrackAttr,
                            'cutoff' => $cutoff,
                            'panId' => $panId,
                                           };

  my $peaks = ApiCommonModel::Model::JBrowseTrackConfig::ChipChipPeakTrackConfig->new({
                                                                                                dataset_name => $dataset,
                                                                                                attribution => $shortAttribution,
                                                                                                study_display_name => $datasetDisplayName,
                                                                                                description => $summary,
                                                                                                query_params => $queryParams,
                                                                                                application_type => $applicationType,
                                                                                                label => $key,
                                                                                                key => $key,
												pan_name => $panName,
												dataset_presenter_id => $datasetPresenterId,
												summary => $summary,
                                                                                              })->getConfigurationObject();
  return $peaks;
}


sub addCnvArray {
  my ($dbh, $result, $projectName, $applicationType) = @_;

  my $sql = "select distinct pan.name
from study.protocolappnode pan
   , study.study s
   , study.studylink sl
where pan.PROTOCOL_APP_NODE_ID = sl.PROTOCOL_APP_NODE_ID
and sl.study_id = s.study_id
and s.name like 'tcruCLBrenerEsmeraldo-like_cghArrayExper_Tarelton_GSE23576_CNV_RSRC%'
order by pan.name";
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my $summary = "Comparative Genomic Hybridization to determine regions of significant Copy Number Variation in <i>T. cruzi</i> strains with strain CL Brener as reference. Type I strains used include: Brazil, Chinata, Colombiana, M78, Montalvania, PalDa1 (clone 9), SylvioX10/4, TCC, TEDa2 (clone 4), TEP6 (clone 5). Type II-VI strains used include: Esmeraldo, M5631, Tu18 (clone 1), Tulahuen, wtCL, Y. Scores from Type I strain is shown in Green and from Type II-VI are show in Brown. Score value represents the number of strains showing CNV , with a postive score implying amplification and a negative score implying deletion with respect to CL Brener. CNV criteria: minimum log2 ratio of signal intensities (test strain/reference) +/- 0.6, minimum number of probes 5. For more details refer the following manuscript: <a href=\"http://www.ncbi.nlm.nih.gov/pmc/articles/PMC3060142/\">Widespread, focal copy number variations (CNV) and whole chromosome aneuploidies in Trypanosoma cruzi strains revealed by array comparative genomic hybridization</a> ";

  while(my ($dataset) = $sh->fetchrow_array()) {

    my $cnv = ApiCommonModel::Model::JBrowseTrackConfig::CnvArrayTrackConfig->new({
                                                                                                dataset_name => $dataset,
                                                                                                study_display_name => "Comparative Genomic Hybridizations of 33 strains",
                                                                                                description => $summary,
                                                                                                application_type => $applicationType,
                                                                                                name => $dataset,
                                                                                              })->getConfigurationObject();
    push @{$result->{tracks}}, $cnv;

  }
  $sh->finish();
}


sub makeChipChipSmoothed {
  my ($dataset, $study, $panName, $panId, $datasetProperties, $chipChipSeqDatasets, $applicationType) = @_;

    my $datasetDisplayName = $chipChipSeqDatasets->{$dataset}->{datasetDisplayName};
    my $summary = $chipChipSeqDatasets->{$dataset}->{summary};
    $summary =~ s/\n/ /g;
    my $shortAttribution = $chipChipSeqDatasets->{$dataset}->{shortAttribution};

    my $datasetKey = $datasetProperties->{$dataset}->{key};
    my $key = $panName;
    my $subTrackAttr = $chipChipSeqDatasets->{$dataset}->{subTrackAttr};

    my $queryParams = {
                            'exp' => $dataset,
                            'sub' => $subTrackAttr,
                            'panId' => $panId,
                                           };

    my $smoothed = ApiCommonModel::Model::JBrowseTrackConfig::ChipChipSmoothedTrackConfig->new({
                                                                                                dataset_name  => $dataset,
                                                                                                attribution => $shortAttribution,
                                                                                                study_display_name => $datasetDisplayName,
                                                                                                description => $summary,
                                                                                                query_params => $queryParams,
                                                                                                application_type => $applicationType,
                                                                                                pan_name => $panName,
                                                                                                cov_max_score_default => 3,
                                                                                                cov_min_score_default => 3,
                                                                                                label => $key,
                                                                                                key => $key,
												summary => $summary,
                                                                                              })->getConfigurationObject();
  
  return $smoothed;
}


sub addNrdbProteinAlignments {
my ($result, $datasetProperties, $nameForFileNames, $organismAbbrev, $projectName, $buildNumber, $applicationType, $datasetProps, $webservicesDir) = @_;
    my $proteinAlignTrack;
    #my $gffUrl = "/a/service/jbrowse/store?data=" . uri_escape_utf8("${nameForFileNames}/nrProteinsToGenomeAlign/result.sorted.gff.gz");
    my $relativePathToGffFile = "${webservicesDir}/UniDB/build-$buildNumber/${nameForFileNames}/genomeAndProteome/gff/nrProteinToGenome.gff.gz";
    my $methodDescription = "<p>NCBI's non redundant collection of proteins (nr) was filtered for deflines matching the Genus of this sequence.  These proteins were aligned using <a href='https://www.ebi.ac.uk/about/vertebrate-genomics/software/exonerate'>exonerate</a>. (protein to genomic sequence)</p>";

    $proteinAlignTrack = ApiCommonModel::Model::JBrowseTrackConfig::NrdbProteinTrackConfig->new({
												project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToGffFile,
                                                                                                 application_type => $applicationType,
                                                                                                 summary => $methodDescription,
                                                                                                })->getConfigurationObject();
    push @{$result->{tracks}}, $proteinAlignTrack;

}

sub addTRNA {
  my ($datasetProps, $result, $applicationType) = @_;
     my $hasTRNA = $datasetProps->{hasTRNA} ? $datasetProps->{hasTRNA} : {};
        if($hasTRNA == 1) {
     my $track = ApiCommonModel::Model::JBrowseTrackConfig::TrnaTrackConfig->new({application_type => $applicationType })->getConfigurationObject();

     push @{$result->{tracks}}, $track;
  }
}


# sub addPopsets {
#   my ($dbh, $result) = @_;

#   my $sql = "select count(*) from apidbtuning.popsetAttributes";

#   my $sh = $dbh->prepare($sql);
#   $sh->execute();
#   my $count = $sh->fetchrow_array();
#   $sh->finish();
#   if($count > 0) {

#     my $track = {storeClass => "JBrowse/Store/SeqFeature/REST",
#                  baseUrl => "/a/service/jbrowse",
#                  type => "JBrowse/View/Track/CanvasFeatures",
#                  glyph => "JBrowse/View/FeatureGlyph/Box",
#                  key => "Popset Isolate Sequence Alignments",
#                  label => "popsetIsolates",
# 		 maxFeatureScreenDensity => 0.03,
#                  region_feature_densities => "function(){return true}",
#                  category => "Sequence Analysis",
#                  displayMode => "compact",
#                  style => {
#                    color => "{popsetColor}",
#                  },
#                  metadata => {
#                    subcategory => "BLAT and Blast Alignments",
#                    trackType => 'Segments',
#                  },
#                  query => {'feature' => "match:IsolatePopset",
#                  },
#                  onClick => {
#                    content => "{popsetDetails}",
#                  },
#                  menuTemplate =>
# 		 [
# 		  {label => "View Details",
# 		   content => "{popsetDetails}",
# 		  },
# 		  {label => "View Popset Sequence Page",
# 		   title => "{popsetDetails}",
# 		   iconClass => "dijitIconDatabase",
# 		   action => "newWindow",
# 		   url => "/a/app/record/popsetSequence/{name}",
# 		  },
# 		 ],
# 		};
#     push @{$result->{tracks}}, $track;
#   }
# }

sub addAntismash {
  my ($result, $nameForFileNames, $webservicesDir, $projectName, $applicationType) = @_;

  # These reference genomes returned no result for antismash so no track should be shown
  my %excludeOrganisms = ("AastaciAPO3" => 1,
                          "Acandida2VRR" => 1,
                          "AeuteichesMF1" => 1,
                          "AinvadansNJM9701" => 1,
                          "AlaibachiiNc14" => 1,
                          "BlactucaeSF5" => 1,
                          "GirregulareDAOMBR486" => 1,
                          "GiwayamaeDAOMBR242034" => 1,
                          "GultimumDAOMBR144" => 1,
                          "HarabidopsidisEmoy2" => 1,
                          "PaphanidermatumDAOMBR444" => 1,
                          "ParrhenomanesATCC12531" => 1,
                          "Pcactorum10300" => 1,
                          "PcapsiciLT1534" => 1,
                          "PcinnamomiGKB4" => 1,
                          "PeffusaR13" => 1,
                          "PinfestansT30-4" => 1,
                          "PinsidiosumPi-s" => 1,
                          "Ppalmivorasbr112.9" => 1,
                          "PparasiticaINRA-310" => 1,
                          "PsojaeP6497" => 1,
                          "PvexansDAOMBR484" => 1,
                          "SdiclinaVS20" => 1,
      );

  return if($excludeOrganisms{$nameForFileNames});

  my $gffUrl = "/a/service/jbrowse/auxiliary?data=${projectName}/antismash/" . uri_escape_utf8("${nameForFileNames}.sorted.gff.gz");


  my $summary = "Secondary metabolite gene clusters as predicted using antiSmash version 7.1 under default parameters";

    my $antiSmashTrack = ApiCommonModel::Model::JBrowseTrackConfig::AntiSmashTrackConfig->new({url_template => $gffUrl,
                                                                                                 application_type => $applicationType,
												 summary => $summary,
												 gene_legend => "<img src='https://microscope.readthedocs.io/en/stable/_images/antiSMASH6_colorcode_features.png'/>",
												 region_legend => "<img src='/a/images/antismash_cluster_colors.png'  height='250' width='250' align=left/>",
                                                                                                })->getConfigurationObject();


  push @{$result->{tracks}}, $antiSmashTrack;
  
}

sub addLongReadRNASeq {
  my ($result, $datasetProperties, $nameForFileNames, $webservicesDir, $projectName, $buildNumber, $applicationType) = @_;

   my $LongReadRnaSeqDatasets = $datasetProperties->{longreadrnaseq} ? $datasetProperties->{longreadrnaseq} : {};

   foreach my $dataset (keys %$LongReadRnaSeqDatasets){
    next unless($dataset =~ /nanopore_rnaSeqNextflow/);


    my $datasetName = $LongReadRnaSeqDatasets->{$dataset}->{datasetName};
    my $datasetDisplayName = $LongReadRnaSeqDatasets->{$dataset}->{datasetDisplayName};
    my $datasetPresenterId = $LongReadRnaSeqDatasets->{$dataset}->{datasetPresenterId};
    my $summary = $LongReadRnaSeqDatasets->{$dataset}->{summary};
    $summary =~ s/\n/ /g;
    my $shortAttribution = $LongReadRnaSeqDatasets->{$dataset}->{shortAttribution}; 

    #----------------------------


    #my $gffUrl = "/a/service/jbrowse/store?data=" . uri_escape_utf8("${nameForFileNames}/longReadRNASeq/gff/${datasetName}/${datasetName}\_sorted_updated.gff.gz");
    my $relativePathToGffFile = "${nameForFileNames}/longReadRNASeq/gff/${datasetName}/${datasetName}\_sorted_updated.gff.gz";      

      my $featuresTrack = ApiCommonModel::Model::JBrowseTrackConfig::LongReadRNASeqTrackConfig->new({
												#url_template => $gffUrl,
												project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToGffFile,
                                                                                                application_type => $applicationType,
                                                                                                key => "${datasetDisplayName} all models",
                                                                                                label => "${datasetName}_all_models",
												summary => $summary,
												type => "NeatCanvasFeatures/View/Track/NeatFeatures",
												url => "/a/app/embed-record/long_read_transcript/{transcript_id}_${datasetPresenterId}?tables=SampleInfo",
                                                                                              })->getConfigurationObject();


      my $highConfidenceFeaturesTrack = ApiCommonModel::Model::JBrowseTrackConfig::LongReadRNASeqTrackConfig->new({
                                                                                                #url_template => $gffUrl,
                                                                                                project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToGffFile,
                                                                                                application_type => $applicationType,
                                                                                                key => "${datasetDisplayName} high confidence models (> 5 supporting reads)",
                                                                                                label => "${datasetName}_high_confidence_models",
                                                                                                summary => $summary,
                                                                                                type => "EbrcTracks/View/Track/GFFByReadCount",
												url => "/a/app/embed-record/long_read_transcript/{transcript_id}_${datasetPresenterId}?tables=SampleInfo",
                                                                                              })->getConfigurationObject();

    push @{$result->{tracks}}, $highConfidenceFeaturesTrack;
	push @{$result->{tracks}}, $featuresTrack; 


    #----------------------------
    my $metadataFile = "${webservicesDir}/$projectName/build-${buildNumber}/${nameForFileNames}/longReadRNASeq/bam/${datasetName}/metadata.txt";

    open(FILE, $metadataFile) or die "Cannot open file $metadataFile for reading: $!";
    while(<FILE>) {
      chomp;
      my ($sampleType, $sampleFile, $sampleDisplayName) = split(/\t/, $_);


      #my $bamUrl = "/a/service/jbrowse/store?data=" . uri_escape_utf8("${nameForFileNames}/longReadRNASeq/bam/${datasetName}/${sampleFile}");
       my $relativePathToBamFile = "${nameForFileNames}/longReadRNASeq/bam/${datasetName}/${sampleFile}";

       my $alignment = ApiCommonModel::Model::JBrowseTrackConfig::AlignmentsTrackConfig->new({	
												#url_template => "$bamUrl",
                                                                                                project_name => $projectName,
                                                                                                build_number => $buildNumber,
                                                                                                relative_path_to_file => $relativePathToBamFile,
												application_type => $applicationType,
												key => "${sampleDisplayName} long read RNA-Seq",
												label => "${sampleDisplayName} long read RNA-Seq",
												type => "JBrowse/View/Track/Alignments2",
												category => "Transcriptomics",
												color_fwd_strand => "#898FD8",
												color_rev_strand => "#EC8B8B",
												trackType => 'Long Read Bam alignment',
                                                                                              })->getConfigurationObject();

      push @{$result->{tracks}}, $alignment;
    }
  }
}



1;


package _Tree; 

use strict;

sub getName {$_[0]->{_name}}

sub setAlreadySeen {$_[0]->{_seen} = $_[1]}
sub getAlreadySeen {$_[0]->{_seen}}

sub setAbbrev {$_[0]->{_abbrev} = $_[1]}
sub getAbbrev {$_[0]->{_abbrev}}

sub setFeatureFilters {$_[0]->{_feature_filters} = $_[1]}
sub getFeatureFilters {$_[0]->{_feature_filters}}

sub setMetadata {$_[0]->{_metadata} = $_[1]}
sub getMetadata {$_[0]->{_metadata}}

sub getParent {$_[0]->{_parent}}

sub getChildren {$_[0]->{_children} || [] }

sub addChild {push @{$_[0]->{_children}}, $_[1]}

sub isLeaf {
  my ($self) = @_;
  my $children = $self->getChildren();
  return scalar @$children == 0;
}

sub isRoot {
  my ($self) = @_;
  return !defined($self->getParent());
}

sub new {
  my ($class, $args) = @_;

  return bless $args, $class;
}

1;
