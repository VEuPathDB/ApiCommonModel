package org.apidb.apicommon.model.datasetInjector.custom.TriTrypDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class Lopit extends DatasetInjector {

  @Override
  public void injectTemplates() {
  }


  @Override
  public void addModelReferences() {
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByLOPIT");  
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "LOPITtryp");
  }

  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
