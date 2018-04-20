package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.RNASeq;

public class RNASeqGalinskiMmulatta extends RNASeq {


  @Override
  public void addModelReferences() {

    super.addModelReferences();

    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                              "GeneQuestions.GenesByRNASeq" + getDatasetName());

  }

  @Override
  public void injectTemplates() {
      setShortAttribution();



      String projectName = getPropValue("projectName");
      //String presenterId = getPropValue("presenterId");
      String datasetName = getDatasetName();

      Boolean switchStrandsGBrowse = getPropValueAsBoolean("switchStrandsGBrowse");
      Boolean switchStrandsProfiles = getPropValueAsBoolean("switchStrandsProfiles");

      setPropValue("metadataFileSuffix","");
      setOrganismAbbrevFromDatasetName();

      if(getPropValueAsBoolean("isEuPathDBSite")) {
          setPropValue("includeProjects", projectName + ",EuPathDB");

      } else {
          setPropValue("includeProjects", projectName);
      }

      setPropValue("graphModule", "RNASeq");
      setPropValue("stranded", "");

      String datasetShortDisplayName = getPropValue("datasetShortDisplayName");
      if (datasetShortDisplayName == null || datasetShortDisplayName.equals("")) {
        throw new RuntimeException(datasetName + " datasetShortDisplayName cannot be null");
      }

      injectTemplate("datasetCategory");

      if(getPropValueAsBoolean("isDESeq")) {
            if(getPropValueAsBoolean("isStrandSpecific")) {
                setPropValue("stranded", "Strand Specific ");
                if (switchStrandsProfiles) {
                    setPropValue("antisense","firststrand") ;
                    setPropValue("sense","secondstrand") ;
                }
                else {
                    setPropValue("sense","firststrand") ;
                    setPropValue("antisense","secondstrand") ;
                }

            }
            injectTemplate("DESeqProfileSetParamQuery");

      }

      if(getPropValueAsBoolean("isDEGseq")) {
          injectTemplate("DEGseqProfileSetParamQuery");
      }
      if(getPropValueAsBoolean("isAlignedToAnnotatedGenome")) {
          setPropValue("exprMetric", "fpkm");

          if(getPropValue("graphYAxisDescription") == null) {
              //              setPropValue("graphYAxisDescription", "Transcript levels of fragments per kilobase of exon model per million mapped reads (FPKM). Note that Non-Unique reads are ignored in the expression graphs.  This means that the expression of duplicated genes (or gene families) might be underrepresented.  Please consult the non-unique aligned read tracks in the genome browser to determine if your gene of interest contains non-uniquely aligned reads. The percentile graph shows the ranking of expression for this gene compared to all others in this experiment.");
              //
              setPropValue("graphYAxisDescription", "Transcript levels of fragments per kilobase of exon model per million mapped reads (FPKM). The percentile graph shows the ranking of expression for this gene compared to all others in this experiment.");
          }

          String exprMetric = getPropValue("exprMetric");

          if(getPropValueAsBoolean("isStrandSpecific")) {
              setPropValue("stranded", "Strand Specific ");
              if (switchStrandsGBrowse) {
                  setPropValue("metadataFileSuffix","_alt");
              }

              if (switchStrandsProfiles) {
                  setPropValue("antisense","firststrand") ;
                  setPropValue("sense","secondstrand") ;
              }
              else {
                  setPropValue("sense","firststrand") ;
                  setPropValue("antisense","secondstrand") ;
              }

              setPropValue("graphVisibleParts", exprMetric + "_sense");
              injectTemplate("pathwayGraphs");

              injectTemplate("profileSampleAttributesCategory");
              injectTemplate("profileAttributeQueriesStrandSpecificRNASeq");
              injectTemplate("profileAttributeRef");

              injectTemplate("profileMinMaxAttributesRnaSenseCategory");
              injectTemplate("profileMinMaxAttributeRnaSenseRef");
              injectTemplate("profileMinMaxAttributeRnaSenseQueries");

              injectTemplate("profileMinMaxAttributesRnaAntisenseCategory");
              injectTemplate("profileMinMaxAttributeRnaAntisenseRef");
              injectTemplate("profileMinMaxAttributeRnaAntisenseQueries");


              String senseExprGraphAttr = datasetName + "_sense_expr_graph";
              String antisenseExprGraphAttr = datasetName + "_antisense_expr_graph";

              String sensePctGraphAttr = datasetName + "_sense_pct_graph";
              String antisensePctGraphAttr = datasetName + "_antisense_pct_graph";

              String pathwayGraphAttr = datasetName + "_ss_expr_graph_pr";

              // These are used for the question
              setPropValue("exprGraphAttr", senseExprGraphAttr + "," + antisenseExprGraphAttr);
              setPropValue("pctGraphAttr", sensePctGraphAttr + "," + antisensePctGraphAttr);

              injectTemplate("rnaSeqSsExpressionGraphAttributes");
              injectTemplate("rnaSeqSsExpressionGraphAttributesPathwayRecord");

              // Inject the text attributes into the ontology for the results summary page
              setPropValue("graphTextAttrName", senseExprGraphAttr);
              injectTemplate("graphTextAttributeCategory");

              setPropValue("graphTextAttrName", antisenseExprGraphAttr);
              injectTemplate("graphTextAttributeCategory");


              setPropValue("graphTextAttrName", sensePctGraphAttr);
              injectTemplate("graphTextAttributeCategory");


              setPropValue("graphTextAttrName", antisensePctGraphAttr);
              injectTemplate("graphTextAttributeCategory");

              setPropValue("graphTextAttrName", pathwayGraphAttr);
              injectTemplate("graphTextAttributeCategoryPathwayRecord");


              injectTemplate("rnaSeqProfileSetParamQuery");
              injectTemplate("rnaSeqPctProfileSetParamQuery");

              injectTemplate("rnaSeqGraph");
          } else {
              //              setPropValue("sense","unstranded") ;
              setPropValue("graphVisibleParts", exprMetric);
              injectTemplate("pathwayGraphs");

              setPropValue("graphVisibleParts", exprMetric + ",percentile");


              String exprGraphAttr = datasetName + "_expr_graph";
              String pctGraphAttr = datasetName + "_pct_graph";

              String pathwayGraphAttr = datasetName + "_expr_graph_pr";

              setPropValue("exprGraphAttr", exprGraphAttr);
              setPropValue("pctGraphAttr", pctGraphAttr);

              injectTemplate("rnaSeqExpressionGraphAttributes");
              injectTemplate("rnaSeqExpressionGraphAttributesPathwayRecord");
              injectTemplate("rnaSeqProfileSetParamQuery");
              injectTemplate("rnaSeqPctProfileSetParamQuery");


              injectTemplate("profileMinMaxAttributesCategory");
              injectTemplate("profileMinMaxAttributeRef");
              injectTemplate("profileMinMaxAttributeQueries");

              // Add text attribute to the categories ontology
              setPropValue("graphTextAttrName", exprGraphAttr);
              injectTemplate("graphTextAttributeCategory");

              setPropValue("graphTextAttrName", pctGraphAttr);
              injectTemplate("graphTextAttributeCategory");

              setPropValue("graphTextAttrName", pathwayGraphAttr);
              injectTemplate("graphTextAttributeCategoryPathwayRecord");

              injectTemplate("rnaSeqGraph");


              if(!projectName.equals("EuPathDB")) {
                  injectTemplate("profileSampleAttributesCategory");
                  injectTemplate("profileAttributeQueries");
                  injectTemplate("profileAttributeRef");
              }
          }

          if(getPropValueAsBoolean("hasMultipleSamples")) {
              injectTemplate("rnaSeqFoldChangeQuestion");
              //              injectTemplate("rnaSeqFoldChangeCategories");
              setPropValue("searchCategory", "searchCategory-transcriptomics-fold-change");
              setPropValue("questionName", "GeneQuestions.GenesByRNASeq" + getDatasetName());
              injectTemplate("internalGeneSearchCategory");
          }

          if(getPropValueAsBoolean("isDESeq")) {
              injectTemplate("rnaSeqDESeqQuestion");
              setPropValue("searchCategory", "searchCategory-transcriptomics-differential-expression");
              setPropValue("questionName", "GeneQuestions.GenesByRNASeq" + getDatasetName() + "DESeq");
              injectTemplate("internalGeneSearchCategory");
          }
          if(getPropValueAsBoolean("isDEGseq")) {
              injectTemplate("rnaSeqDEGseqQuestion");
              setPropValue("searchCategory", "searchCategory-transcriptomics-differential-expression-degseq");
              setPropValue("questionName", "GeneQuestions.GenesByRNASeq" + getDatasetName() + "DEGseq");
              injectTemplate("internalGeneSearchCategory");
          }

if(getPropValueAsBoolean("includeProfileSimilarity")) {
              injectTemplate("rnaSeqProfileSimilarityQuestion");
              injectTemplate("rnaSeqProfileSimilarityParamQuery");
              injectTemplate("rnaSeqProfileSimilarityTimeShiftParamQuery");

              setPropValue("searchCategory", "searchCategory-similarity");
              setPropValue("questionName", "GeneQuestions.GenesByRNASeq" + getDatasetName() + "ProfileSimilarity");

              injectTemplate("internalGeneSearchCategory");
              injectTemplate("similarityGraph");
          }


          if(getPropValue("graphPriorityOrderGrouping").equals("")) {
              setPropValue("graphPriorityOrderGrouping", "1");
          }

 // need to make sure there are no single quotes in the descrip
         String datasetDescrip = getPropValue("datasetDescrip");
         setPropValue("datasetDescrip", datasetDescrip.replace("'", ""));

        setPropValue("isGraphCustom", "false");
          injectTemplate("genePageGraphDescriptions");

          injectTemplate("datasetExampleGraphDescriptions");

      }

      // remove ':' which is gbrowse category separator.
      String organismAbbrevDisplay = getPropValue("organismAbbrevDisplay");
      setPropValue("organismAbbrevDisplay", organismAbbrevDisplay.replace(":", ""));

      injectTemplate("rnaSeqCoverageTrack");
      setPropValue("gbrowseTrackName", getDatasetName() + "Coverage");
      injectTemplate("gbrowseTrackCategory");

      injectTemplate("rnaSeqCoverageTrackUnlogged");
      setPropValue("gbrowseTrackName", getDatasetName() + "CoverageUnlogged");
      injectTemplate("gbrowseTrackCategory");




      String showIntronJunctions = getPropValue("showIntronJunctions");
      if(Boolean.parseBoolean(showIntronJunctions)) {

          String experimentName = datasetName.replace("_rnaSeq_RSRC", "");


          //String experimentName = experimentRsrc.replaceFirst("RSRC", "");
          setPropValue("experimentName", experimentName);

          // String organismAbbrev = getPropValue("organismAbbrev");
          if(projectName.equals("HostDB")) {
              setPropValue("intronSizeLimit", "100000");
          }
          else {
              setPropValue("intronSizeLimit", "9000");
          }

          injectTemplate("rnaSeqJunctionsTrack");
          setPropValue("gbrowseTrackName", getDatasetName() + "Junctions");
          injectTemplate("gbrowseTrackCategory");
      }

  }                                                          
}
