package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class ChIPChip extends DatasetInjector {

  public void injectTemplates() {

  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByChIPchipPlasmo"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
