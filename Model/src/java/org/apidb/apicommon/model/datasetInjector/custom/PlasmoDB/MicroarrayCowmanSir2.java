package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayCowmanSir2 extends CusomGenePageExpressionGraphs {


  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Cowman::Sir2KO"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Cowman::Ver2"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByCowmanSir2FoldChange"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByCowmanSir2Percentile"); 
  }


}
