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

  public void injectTemplates() {
      // TODO: split out param query templates (not urgent)
      // TODO: which graphs for the gene record page?

      String projectName = getPropValue("projectName");
      String isEuPathDBSite = getPropValue("isEuPathDBSite");
      if(Boolean.parseBoolean(isEuPathDBSite)) {
          setPropValue("includeProjects", projectName + ",EuPathDB");

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

      String hasJunctions = getPropValue("hasJunctions");
      if(Boolean.parseBoolean(hasJunctions)) {
          String organism = getPropValue("organism");
          char firstLetter = organism.charAt(0);
          String[] orgWords = organism.split(" ");
          String orgAbbrev = firstLetter + ". " + orgWords[1];

          setPropValue("orgAbbrev", orgAbbrev);

          injectTemplate("rnaSeqJunctionsTrack");
      }

  }

  public void addModelReferences() {
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                    "GenesByRNASeq" + getDatasetName());
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                    "GenesByRNASeq" + getDatasetName() + "PValue");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                    "GenesByRNASeq" + getDatasetName() + "Percentile");
  }
  
  // declare properties required beyond those inherited from the datasetPresenter
  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
      String [][] declaration = {{"isTimeSeries", ""},
                                 {"hasFishersExactTestData", ""},
                                 {"isPairedEnd", ""},
                                 {"isEuPathDBSite", ""},
                                 {"graphColor", ""},
                                 {"graphBottomMarginSize", ""},
                                 {"hasJunctions", ""},
                                 {"organism", ""},
                                 {"organismShortName", ""}


      };

    return declaration;
  }
}
