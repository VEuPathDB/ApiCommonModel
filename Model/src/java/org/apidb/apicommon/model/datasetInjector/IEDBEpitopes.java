package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class IEDBEpitopes extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesWithEpitopes");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "Epitopes");
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
