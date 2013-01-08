package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class IsolatesSuRFLP extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "IsolateQuestions.IsolateByRFLPGenotype"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "IsolateQuestions.IsolateByGenotypeNumber"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
