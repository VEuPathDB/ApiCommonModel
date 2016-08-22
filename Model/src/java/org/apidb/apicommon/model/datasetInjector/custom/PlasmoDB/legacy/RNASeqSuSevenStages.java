package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB.legacy;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class RNASeqSuSevenStages extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Su::PfSevenStages"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRNASeqSuSevenStages"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRNASeqSuSevenStagesPValue"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRNASeqSuSevenStagesPercentile"); 
      addWdkReference("SequenceRecordClasses.SequenceRecordClass", "gbrowse_track", "pfal3D7_Su_seven_stages_rnaSeq_RSRC_RNASeqCoverage"); 
  }

}

