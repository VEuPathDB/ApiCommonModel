package org.apidb.apicommon.model.datasetInjector.custom.CryptoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class RTPcrKissinger extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRtPcrFoldChange"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByCryptoRtpcrProfileSimilarity"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Kissinger::KissingerRtPcrProfiles"); 
  }



}

