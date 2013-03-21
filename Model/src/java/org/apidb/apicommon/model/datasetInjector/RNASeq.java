package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class RnaSeqInjector extends  DatasetInjector {
  
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
      String isEuPathDBSite = getPropValue("isEuPathDBSite");
      if(Boolean.parseBoolean(isEuPathDBSite)) {
          setPropValue("includeProjects", projectName + ",EuPathDB");
          // TODO: split out param query templates and add them here!
      } else {
          setPropValue("includeProjects", projectName);
      }

      String isPairedEnd = getPropValue("isPairedEnd");
      if(Boolean.parseBoolean(isPairedEnd)) {
          setPropValue("exprMetric", "fpkm");
      } else {
          setPropValue("exprMetric", "rpkm");
      }

      injectTemplate("rnaSeqExpressionGraphAttributes");

      injectTemplate("rnaSeqProfileSetParamQuery");
      injectTemplate("rnaSeqPctProfileSetParamQuery");

      injectTemplate("rnaSeqFoldChangeQuestion");
      injectTemplate("rnaSeqPercentileQuestion");

      String hasFishersExactTest = getPropValue("hasFishersExactTestData");
      if(Boolean.parseBoolean(hasFishersExactTest)) {
          injectTemplate("rnaSeqFoldChangeWithPValueQuestion");
      }


      injectTemplate("rnaSeqCoverageTrack");

      injectTemplate("rnaSeqStrandNonSpecificGraph");



      /*    


    injectTemplate("rnaSeqJunctionsTrack");
      */
  }

  public void addModelReferences() {
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
        "GeneQuestions.GenesByRNASeq_" + getDatasetName() + "_FoldChangePValue");
  }
  
  // declare properties required beyond those inherited from the datasetPresenter
  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
      String [][] declaration = {{"isTimeSeries", ""},
                                 {"hasFishersExactTestData", ""},
                                 {"isPairedEnd", ""},
                                 {"isEuPathDBSite", ""},
                                 {"graphColor", ""},
                                 {"graphBottomMarginSize", ""}

      };

    return declaration;
  }
}
