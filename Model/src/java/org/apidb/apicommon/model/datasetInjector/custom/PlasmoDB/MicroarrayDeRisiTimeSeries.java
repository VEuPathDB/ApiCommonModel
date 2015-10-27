package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayDeRisiTimeSeries extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "OverlayIRBC::Ver2"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "DeRisi::Combined"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByExpressionTiming"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByProfileSimilarity"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByMicroarrayPercentileDerisi"); 
  }


}
