package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class IsolateVocabulary extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByHost"); 
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByIsolationSource"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
