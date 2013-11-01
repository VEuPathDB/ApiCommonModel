package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class RNASeq extends  DatasetInjector {
  
  /*
   * getPropValues() gets the property values provided by the datasetPresenter
   * xml file. they are validated against the names provided in
   * getPropertyNames(). in the code below, the whole bundle is passed to each
   * of the templates even though a given template might not need all of them.
   * this is just convenience, rather than tailoring the list per template, it
   * is safe to pass all in, because unneeded ones will be ignored.
   */

  @Override
  public void injectTemplates() {
      setShortAttribution();

      String projectName = getPropValue("projectName");

      String datasetName = getDatasetName();

      setOrganismAbbrevFromDatasetName();
      setOrganismAbbrevInternalFromDatasetName();

      if(getPropValueAsBoolean("isEuPathDBSite")) {
          setPropValue("includeProjects", projectName + ",EuPathDB");

      } else {
          setPropValue("includeProjects", projectName);
      }

      String datasetShortDisplayName = getPropValue("datasetShortDisplayName");
      if (datasetShortDisplayName == null || datasetShortDisplayName.equals("")) {
        throw new RuntimeException(datasetName + " datasetShortDisplayName cannot be null");
      }
      
      setPropValue("graphGenePageSection", "expression");


      if(getPropValueAsBoolean("isAlignedToAnnotatedGenome")) {

          if(getPropValueAsBoolean("hasPairedEnds")) {
              setPropValue("exprMetric", "fpkm");
              setPropValue("graphYAxisDescription", "Transcript levels of fragments per kilobase of exon model per million mapped reads (FPKM).  Stacked bars indicate unique and non-uniquely mapped sequences.  Non-Unique sequences are plotted to indicate the maximum expression potential of this gene.");
          } else {
              setPropValue("exprMetric", "rpkm");
              setPropValue("graphYAxisDescription", "Transcript levels of reads per kilobase of exon model per million mapped reads (RPKM).  Stacked bars indicate unique and non-uniquely mapped sequences.  Non-Unique sequences are plotted to indicate the maximum expression potential of this gene.");
          }

          String exprMetric = getPropValue("exprMetric");

          injectTemplate("rnaSeqAttributeCategory");

          // Strand Specific Could be factored into subclasses
          if(getPropValueAsBoolean("isStrandSpecific")) {

              setPropValue("graphModule", "RNASeq::StrandSpecific");
              setPropValue("graphVisibleParts", exprMetric + "_sense," + exprMetric + "_antisense,percentile_sense,percentile_antisense");


              setPropValue("exprGraphAttr", datasetName + 
                           "_sense_expr_graph," + datasetName + "_antisense_expr_graph");
              setPropValue("pctGraphAttr", datasetName + 
                           "_sense_pct_graph," + datasetName + "_antisense_pct_graph");

              injectTemplate("rnaSeqSsExpressionGraphAttributes");
              injectTemplate("rnaSeqSsProfileSetParamQuery");
              injectTemplate("rnaSeqSsPctProfileSetParamQuery");
              injectTemplate("rnaSeqStrandSpecificGraph");
      
          } else {

              setPropValue("graphModule", "RNASeq::StrandNonSpecific");
              setPropValue("graphVisibleParts", exprMetric + ",percentile");

              setPropValue("exprGraphAttr", datasetName + "_expr_graph");
              setPropValue("pctGraphAttr", datasetName + "_pct_graph");

              injectTemplate("rnaSeqExpressionGraphAttributes");
              injectTemplate("rnaSeqProfileSetParamQuery");
              injectTemplate("rnaSeqPctProfileSetParamQuery");
              injectTemplate("rnaSeqStrandNonSpecificGraph");
          }


          if(getPropValueAsBoolean("hasMultipleSamplesForFoldChange")) {

              if(getPropValueAsBoolean("hasFishersExactTestData")) {
                  injectTemplate("rnaSeqFoldChangeWithPValueQuestion");
                  injectTemplate("rnaSeqFoldChangeWithPValueCategories");
              }

              injectTemplate("rnaSeqFoldChangeQuestion");
              injectTemplate("rnaSeqFoldChangeCategories");
          }

          injectTemplate("rnaSeqPercentileQuestion");
          injectTemplate("rnaSeqPercentileCategories");


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


      injectTemplate("rnaSeqCoverageTrack");

      String hasJunctions = getPropValue("hasJunctions");
      if(Boolean.parseBoolean(hasJunctions)) {
          injectTemplate("rnaSeqJunctionsTrack");
      }

  }


  @Override
  public void addModelReferences() {
      if(getPropValueAsBoolean("isAlignedToAnnotatedGenome")) {

          if(getPropValueAsBoolean("isStrandSpecific")) {
              setPropValue("graphModule", "RNASeq::StrandSpecific");
          } else {
              setPropValue("graphModule", "RNASeq::StrandNonSpecific");
	  }
	  addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", getPropValue("graphModule") + getDatasetName() ); 

          if(getPropValueAsBoolean("hasMultipleSamplesForFoldChange")) {

              if(getPropValueAsBoolean("hasFishersExactTestData")) {
                  addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                                  "GeneQuestions.GenesByRNASeq" + getDatasetName() + "PValue");
              }

              addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                              "GeneQuestions.GenesByRNASeq" + getDatasetName());

          }
          addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                          "GeneQuestions.GenesByRNASeq" + getDatasetName() + "Percentile");
      }
  }
  
  // declare properties required beyond those inherited from the datasetPresenter
  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
      String [][] declaration = {
                                 {"hasFishersExactTestData", ""},
                                 {"isEuPathDBSite", ""},
                                 {"graphColor", ""},
                                 {"graphBottomMarginSize", ""},
                                 {"hasJunctions", ""},
                                 {"isAlignedToAnnotatedGenome", ""},
                                 {"hasMultipleSamplesForFoldChange", ""},
                                 {"graphXAxisSamplesDescription", "will show up on the gene record page next to the graph"},
                                 {"graphPriorityOrderGrouping", "numeric grouping / ordering of graphs on the gene record page"},
                                 {"optionalQuestionDescription", "html text to be appended to the descriptions of all questions"},
                                 {"graphForceXLabelsHorizontal", "should the x axis labels be always horiz"},
      };

    return declaration;
  }
}
