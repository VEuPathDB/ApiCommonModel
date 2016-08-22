package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphsAndCoverage;

public class RNASeqReidNcDay3 extends CusomGenePageExpressionGraphsAndCoverage {

  @Override
  public void addModelReferences() {
 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByNcLivRNASeqExpressionPercentile"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Reid::NcRnaSeq" );
  }
}
