package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class GOAssociations extends DatasetInjector {

  @Override
  public void injectTemplates() {
  }

  @Override
  public void addModelReferences() {
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByGoTerm");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "table", "GoTerms");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "attribute", "ann_go_function");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "attribute", "ann_go_process");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "attribute", "ann_go_component");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "attribute", "pred_go_function");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "attribute", "pred_go_process");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "attribute", "pred_go_component");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }

  
}
