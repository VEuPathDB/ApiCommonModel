package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class SpliceSites extends  DatasetInjector {
  
  /*
   * getPropValues() gets the property values provided by the datasetPresenter
   * xml file. they are validated against the names provided in
   * getPropertyNames(). in the code below, the whole bundle is passed to each
   * of the templates even though a given template might not need all of them.
   * this is just convenience, rather than tailoring the list per template, it
   * is safe to pass all in, because unneeded ones will be ignored.
   */

  public void injectTemplates() {
      String projectName = getPropValue("projectName");
      String datasetName = getDatasetName();

      setOrganismAbbrevFromDatasetName();
      setOrganismAbbrevInternalFromDatasetName();

      if(getPropValueAsBoolean("isEuPathDBSite")) {
          setPropValue("includeProjects", projectName + ",EuPathDB");

      } else {
          setPropValue("includeProjects", projectName);
      }

      setPropValue("graphGenePageSection", "expression");

      setGraphModule();

      if(getPropValueAsBoolean("hasPairedEnds")) {
	  setPropValue("exprMetric", "fpkm");
	  setPropValue("graphYAxisDescription", "log 2 (normalized tag count)");
      } else {
	  setPropValue("exprMetric", "rpkm");
	  setPropValue("graphYAxisDescription", "log 2 (normalized tag count)");
      }

      String exprMetric = getPropValue("exprMetric");
      setPropValue("graphVisibleParts", exprMetric + ",percentile");

      setPropValue("exprGraphAttr", datasetName + "_expr_graph");
      setPropValue("pctGraphAttr", datasetName + "_pct_graph");

      injectTemplate("spliceSitesAttributeCategory");
      injectTemplate("spliceSitesExpressionGraphAttributes");
      injectTemplate("spliceSitesGraph");

  
      if(getPropValueAsBoolean("hasMultipleSamples")) {
	  injectTemplate("spliceSitesProfileSetParamQuery");
	  injectTemplate("spliceSitesFoldChangeQuestion");

	  injectTemplate("spliceSitesProfileSetsQuery");
	  injectTemplate("spliceSitesDifferentialQuestion");
      }

      injectTemplate("spliceSitesPctProfileSetParamQuery");
      injectTemplate("spliceSitesPercentileQuestion");

      if(getPropValue("graphPriorityOrderGrouping").equals("")) {
	  setPropValue("graphPriorityOrderGrouping", "5");
      }

      setPropValue("isGraphCustom", "false");
      injectTemplate("genePageGraphDescriptions") ;    
  }


    protected void setGraphModule() {
	setPropValue("graphModule", "SpliceSites");
    }


  public void addModelReferences() {
      setGraphModule();
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", getPropValue("graphModule") + getDatasetName() ); 

      if(getPropValueAsBoolean("hasMultipleSamples")) {
	  addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
			  "GeneQuestions.GenesBySpliceSites" + getDatasetName() );


	  addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
			  "GeneQuestions.GenesByDifferentialSpliceSites" + getDatasetName());
      }

      addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
		      "GeneQuestions.GenesBySpliceSites" + getDatasetName() + "Percentile");

  }

  
  // declare properties required beyond those inherited from the datasetPresenter
  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
      String [][] declaration = {
                                 {"isEuPathDBSite", ""},
                                 {"hasMultipleSamples", "if experiment has just one sample, then NO fold-change or differential Q"},
                                 {"graphColor", ""},
                                 {"graphBottomMarginSize", ""},
                                 {"graphXAxisSamplesDescription", "will show up on the gene record page next to the graph"},
                                 {"graphPriorityOrderGrouping", "numeric grouping / ordering of graphs on the gene record page"},
                                 {"graphForceXLabelsHorizontal", "should the x axis labels be always horiz"},
                                 {"optionalQuestionDescription", "html text to be appended to the descriptions of all questions"},
      };

    return declaration;
  }
}
