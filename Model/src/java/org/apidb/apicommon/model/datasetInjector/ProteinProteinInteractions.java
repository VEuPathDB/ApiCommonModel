package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class ProteinProteinInteractions extends DatasetInjector {

  @Override
  public void injectTemplates() {
  }

  @Override
  public void addModelReferences() {
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByProteinProteinInteraction");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "Y2hInteractions");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }



}
