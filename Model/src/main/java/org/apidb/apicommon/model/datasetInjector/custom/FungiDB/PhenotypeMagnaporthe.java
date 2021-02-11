package org.apidb.apicommon.model.datasetInjector.custom.FungiDB;


import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class PhenotypeMagnaporthe extends DatasetInjector {

  @Override
  public void injectTemplates() {
  }

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByPhenotype_mory70-15_phenotype_Magnaporthe_Pheno_RSRC"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "Phenotype"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByPhenotypeText");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
