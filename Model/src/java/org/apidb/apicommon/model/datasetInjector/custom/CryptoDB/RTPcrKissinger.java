package org.apidb.apicommon.model.datasetInjector.custom.CryptoDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class RTPcrKissinger extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRtPcrFoldChange"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByCryptoRtpcrProfileSimilarity"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Kissinger::KissingerRtPcrProfiles"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}

