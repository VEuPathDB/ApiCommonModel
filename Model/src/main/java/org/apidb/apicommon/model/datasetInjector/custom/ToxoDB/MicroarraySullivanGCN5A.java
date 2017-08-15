package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarraySullivanGCN5A extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Sullivan::GCN5A"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByToxoFoldChangeSullivan"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByExpressionPercentileSullivan"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByToxoFoldChangePageSullivan"); 
  }


}
