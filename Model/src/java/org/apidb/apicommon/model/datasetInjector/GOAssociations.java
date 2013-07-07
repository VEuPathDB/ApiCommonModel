package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class GOAssociations extends DatasetInjector {

  @Override
  public void injectTemplates() {
  }

  @Override
  public void addModelReferences() {
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByGoTerm");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "GoTerms");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "ann_go_function");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "ann_go_process");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "ann_go_component");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "pred_go_function");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "pred_go_process");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "pred_go_component");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }

  
}
