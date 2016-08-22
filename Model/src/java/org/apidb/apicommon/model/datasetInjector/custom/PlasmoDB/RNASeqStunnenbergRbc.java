package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphsAndCoverage;

public class RNASeqStunnenbergRbc extends CusomGenePageExpressionGraphsAndCoverage {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Stunnenberg::PfRBCRnaSeq"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRNASeqPfRBCFoldChange"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRNASeqPfRBCExprnPercentile"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRNASeqPfRBCFoldChangePValue"); 
      addWdkReference("SequenceRecordClasses.SequenceRecordClass", "gbrowse_track", "pfal3D7_Stunnenberg_rnaSeq_RSRC_RNASeqCoverage"); 
  }
}
