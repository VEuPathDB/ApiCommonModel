package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphsAndCoverage;

public class RNASeqBoothroydOocyst extends CusomGenePageExpressionGraphsAndCoverage {

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.ToxoGenesByBoothroydRNASeqOocystFC"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.ToxoGenesByBoothroydRNASeqOocystPct"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.ToxoGenesByBoothroydRNASeqOocystPValue"); 
  }



}
