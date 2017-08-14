package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayRoosBrady extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByTimeSeriesFoldChangeBradyRoos"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByTimeSeriesFoldChangeBradyFl"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByTimeSeriesFoldChangeBradyBoothroyd"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.ToxoGenesByDifferentialMeanExpression"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByTimeSeriesFoldChangeBradyRoosPct"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByTimeSeriesFoldChangeBradyFlPct"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByTimeSeriesFoldChangeBradyBoothroydPct"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.ToxoGenesByDifferentialMeanExpressionPct"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Dzierszinski::TzBz"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Roos::TzBz"); 
  }


}
