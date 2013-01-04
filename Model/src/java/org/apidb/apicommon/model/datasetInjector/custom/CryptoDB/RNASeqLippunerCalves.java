package org.apidb.apicommon.model.datasetInjector.custom.CryptoDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class RNASeqLippunerCalves extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Lippuner::CpSimpleRNASeq"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByFoldChangeCparvumLippuner"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByExprPercentileCpLippuner"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}

