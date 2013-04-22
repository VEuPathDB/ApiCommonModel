package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class RNASeqRoosTachy extends CusomGenePageExpressionGraphs {

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.ToxoGenesByGregoryRNASeqTsFC"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestios.ToxoGenesByGregoryRNASeqTsPValue"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.ToxoGenesByGregoryRNASeqTsPct"); 
  }


}
