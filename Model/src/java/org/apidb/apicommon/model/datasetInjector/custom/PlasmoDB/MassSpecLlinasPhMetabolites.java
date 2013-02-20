package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class MassSpecLlinasPhMetabolites extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("CompoundRecordClasses.CompoundRecordClass", "profile_graph", "Llinas::pHMetabolite"); 
      addWdkReference("CompoundRecordClasses.CompoundRecordClass", "question", "CompoundQuestions.CompoundsByFoldChange");
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}

