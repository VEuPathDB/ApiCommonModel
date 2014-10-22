package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphsAndCoverage;

public class RNASeqSibleyBrady extends CusomGenePageExpressionGraphsAndCoverage {

  @Override
  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.ToxoGenesBySibleyRNASeqBradyzoitePct"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Sibley::TgME49Bradyzoite" ); 
  }


}
