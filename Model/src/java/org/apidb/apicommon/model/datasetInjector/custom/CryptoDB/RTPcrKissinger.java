package org.apidb.apicommon.model.datasetInjector.custom.CryptoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class RTPcrKissinger extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRtPcrFoldChange"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByCryptoRtpcrProfileSimilarity"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Kissinger::KissingerRtPcrProfiles"); 
  }



}

