package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class RNASeqReidNcDay3 extends CusomGenePageExpressionGraphs {

  public void addModelReferences() {
 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByNcLivRNASeqExpressionPercentile"); 
  }


}