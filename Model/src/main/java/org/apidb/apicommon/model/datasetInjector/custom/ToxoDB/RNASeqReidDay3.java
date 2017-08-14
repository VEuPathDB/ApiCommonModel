package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphsAndCoverage;

public class RNASeqReidDay3 extends CusomGenePageExpressionGraphsAndCoverage {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByTgVegRNASeqExpressionPercentile"); 

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Reid::TgVEGRnaSeq" ); 
  }


}
