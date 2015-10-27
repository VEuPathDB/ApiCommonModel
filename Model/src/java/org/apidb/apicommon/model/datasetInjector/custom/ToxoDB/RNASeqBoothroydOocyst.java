package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphsAndCoverage;

public class RNASeqBoothroydOocyst extends CusomGenePageExpressionGraphsAndCoverage {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.ToxoGenesByBoothroydRNASeqOocystFC"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.ToxoGenesByBoothroydRNASeqOocystPct"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Boothroyd::TgM4RnaSeqOocystTS" ); 
      //addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.ToxoGenesByBoothroydRNASeqOocystPValue"); 
  }



}
