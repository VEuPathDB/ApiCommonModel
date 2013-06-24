package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphsAndCoverage;

public class RNASeqSibleyBrady extends CusomGenePageExpressionGraphsAndCoverage {

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.ToxoGenesBySibleyRNASeqBradyzoitePct"); 
  }


}
