package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphsAndCoverage;

public class RNASeqSibleyBrady extends CusomGenePageExpressionGraphsAndCoverage {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.ToxoGenesBySibleyRNASeqBradyzoitePct"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Sibley::TgME49Bradyzoite" ); 
  }


}
