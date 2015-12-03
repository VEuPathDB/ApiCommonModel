package org.apidb.apicommon.model.datasetInjector;

import java.util.List;

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
      //String presenterId = getPropValue("presenterId");
      String datasetName = getDatasetName();

      // TODO : get this value from Presenter
      setPropValue("switchStrands", "0");
      
      setOrganismAbbrevFromDatasetName();

      if(getPropValueAsBoolean("isEuPathDBSite")) {
          setPropValue("includeProjects", projectName + ",EuPathDB");

      } else {
          setPropValue("includeProjects", projectName);
      }

      String datasetShortDisplayName = getPropValue("datasetShortDisplayName");
      if (datasetShortDisplayName == null || datasetShortDisplayName.equals("")) {
        throw new RuntimeException(datasetName + " datasetShortDisplayName cannot be null");
      }
      
      if(getPropValueAsBoolean("isAlignedToAnnotatedGenome")) {

	  // plas-rbld has NO '%rpkm%' name entries in the study.study table. Are all fpkm then?
          //if(getPropValueAsBoolean("hasPairedEnds")) {
              setPropValue("exprMetric", "fpkm");
              setPropValue("graphYAxisDescription", "Transcript levels of fragments per kilobase of exon model per million mapped reads (FPKM).  Stacked bars indicate unique and non-uniquely mapped sequences.  Non-Unique sequences are plotted to indicate the maximum expression potential of this gene.  The percentile graph shows the ranking of expression for this gene compared to all others in this experiment.");
	      //} else {
              //setPropValue("exprMetric", "rpkm");
              //setPropValue("graphYAxisDescription", "Transcript levels of reads per kilobase of exon model per million mapped reads (RPKM).  Stacked bars indicate unique and non-uniquely mapped sequences.  Non-Unique sequences are plotted to indicate the maximum expression potential of this gene.  The percentile graph shows the ranking of expression for this gene compared to all others in this experiment.");
	      //}

          String exprMetric = getPropValue("exprMetric");

          injectTemplate("rnaSeqAttributeCategory");

          if(getPropValueAsBoolean("isStrandSpecific")) {

      // TODO: Presenter to pass a boolean to switch these
      setPropValue("sense","firststrand") ;
      setPropValue("antisense","secondstrand") ;

      Boolean switchStrands = getPropValueAsBoolean("switchStrands");

              setPropValue("graphVisibleParts", exprMetric + "_sense");
              injectTemplate("pathwayGraphs");

              setPropValue("exprGraphAttr", datasetName + 
                           "_sense_expr_graph," + datasetName + "_antisense_expr_graph");
              setPropValue("pctGraphAttr", datasetName + 
                           "_sense_pct_graph," + datasetName + "_antisense_pct_graph");

              injectTemplate("rnaSeqSsExpressionGraphAttributes");
              injectTemplate("rnaSeqProfileSetParamQuery");
              //injectTemplate("rnaSeqStrandSpecificGraph");
	      injectTemplate("rnaSeqGraph");
          } else {

              //setPropValue("graphModule", "RNASeq::StrandNonSpecific");
              setPropValue("graphModule", "RNASeq");

              setPropValue("graphVisibleParts", exprMetric);
              injectTemplate("pathwayGraphs");

              setPropValue("graphVisibleParts", exprMetric + ",percentile");

              setPropValue("exprGraphAttr", datasetName + "_expr_graph");
              setPropValue("pctGraphAttr", datasetName + "_pct_graph");

              injectTemplate("rnaSeqExpressionGraphAttributes");
              injectTemplate("rnaSeqProfileSetParamQuery");

              //injectTemplate("rnaSeqStrandGraph");
              injectTemplate("rnaSeqGraph");
          }


          if(getPropValueAsBoolean("hasMultipleSamples")) {
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

      // remove ':' which is gbrowse category separator.
      String organismAbbrevDisplay = getPropValue("organismAbbrevDisplay");
      setPropValue("organismAbbrevDisplay", organismAbbrevDisplay.replace(":", ""));

      injectTemplate("rnaSeqCoverageTrack");
      injectTemplate("rnaSeqCoverageTrackUnlogged");

      String showIntronJunctions = getPropValue("showIntronJunctions");
      if(Boolean.parseBoolean(showIntronJunctions)) {
        
          String experimentName = datasetName.replace("_rnaSeq_RSRC", "");
          

          //String experimentName = experimentRsrc.replaceFirst("RSRC", "");
          setPropValue("experimentName", experimentName);

          // String organismAbbrev = getPropValue("organismAbbrev");
          String sampleNamePrefix = ":" + experimentName + "_";
          String sampleNameSuffix = "_rnaSeqSample_RSRC";
          


          List<String> sampleNames = getSampleList(sampleNamePrefix, sampleNameSuffix);
          String subtracks = "";
          for (int i=0; i<sampleNames.size(); i++) {
              String subtrack = sampleNames.get(i);
              if (i == sampleNames.size() -1) {
                  subtracks = subtracks + "'" + subtrack + "';";
              }
              else {
                  subtracks = subtracks + "'" + subtrack + "';\n                  ";
              }
          }
          setPropValue("subtracks", subtracks);

          if(projectName.equals("HostDB")) {
              setPropValue("intronSizeLimit", "100000");
          }
          else {
              setPropValue("intronSizeLimit", "9000");
          }
          setPropValue("subtracks", subtracks);

          injectTemplate("rnaSeqJunctionsTrack");
      }

  }


  @Override
  public void addModelReferences() {
      if(getPropValueAsBoolean("isAlignedToAnnotatedGenome")) {

	  setPropValue("graphModule", "RNASeq");
	  /*  if(getPropValueAsBoolean("isStrandSpecific")) {
              setPropValue("graphModule", "RNASeq::StrandSpecific");
          } else {
              setPropValue("graphModule", "RNASeq::StrandNonSpecific");
	      } */
              addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", getPropValue("graphModule") + getDatasetName() ); 

          if(getPropValueAsBoolean("hasMultipleSamples")) {

              addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                              "GeneQuestions.GenesByRNASeq" + getDatasetName());

          }
          addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                          "GeneQuestions.GenesByRNASeq" + getDatasetName() + "Percentile");
      }
  }
  
  // declare properties required beyond those inherited from the datasetPresenter
  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
      String [][] declaration = {
                                 {"isEuPathDBSite", ""},
                                 {"graphColor", ""},
                                 {"graphSampleLabels", ""},
                                 {"graphBottomMarginSize", ""},
                                 {"showIntronJunctions", ""},
                                 {"isAlignedToAnnotatedGenome", ""},
                                 {"hasMultipleSamples", ""},
                                 {"graphXAxisSamplesDescription", "will show up on the gene record page next to the graph"},
                                 {"graphPriorityOrderGrouping", "numeric grouping / ordering of graphs on the gene record page"},
                                 {"optionalQuestionDescription", "html text to be appended to the descriptions of all questions"},
                                 {"graphForceXLabelsHorizontal", "should the x axis labels be always horiz"},
      };

    return declaration;
  }
}
