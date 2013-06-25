package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphsAndCoverage;

public class RNASeqReidNcDay3 extends CusomGenePageExpressionGraphsAndCoverage {

  public void addModelReferences() {
 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByNcLivRNASeqExpressionPercentile"); 
  }


}
