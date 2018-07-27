package org.apidb.apicommon.model.datasetInjector.custom.FungiDB;


import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class PhenotypeCryptococcusInglis extends DatasetInjector {

  @Override
  public void injectTemplates() {
  }

  @Override
  public void addModelReferences() {
      String datasetName = getDatasetName();
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByTextSearch");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "Phenotype"); 
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }

  
}
