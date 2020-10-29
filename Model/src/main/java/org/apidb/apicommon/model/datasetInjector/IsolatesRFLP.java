package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class IsolatesRFLP extends DatasetInjector {

  @Override
  public void injectTemplates() {
  }

  @Override
  public void addModelReferences() {
      addWdkReference("RflpIsolateRecordClasses.RflpIsolateRecordClass", "question", "RflpIsolateQuestions.BySampleDetails"); 
      addWdkReference("RflpIsolateRecordClasses.RflpIsolateRecordClass", "question", "RflpIsolateQuestions.ByGenotypeNumber"); 
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}


