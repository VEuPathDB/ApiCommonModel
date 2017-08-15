package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayRoosTzLineages extends CusomGenePageExpressionGraphs {


  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.ToxoGenesByArchetypalLinagesStrainsFC"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.ToxoGenesByArchetypalLinagesStrainsPage"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.ToxoGenesByArchetypalLinagesStrainsPct"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.ToxoGenesByArchetypalLinagesTypesPage"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.ToxoGenesByArchetypalLinagesTypesPct"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Roos::ToxoLineages::Ver1"); 
  }


}
