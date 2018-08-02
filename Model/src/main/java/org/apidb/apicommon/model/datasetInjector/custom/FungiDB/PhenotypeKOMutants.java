package org.apidb.apicommon.model.datasetInjector.custom.FungiDB;


import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class PhenotypeKOMutants extends DatasetInjector {

  @Override
  public void injectTemplates() {
  }

  @Override
  public void addModelReferences() {
      String datasetName = getDatasetName();
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", datasetName + "_Phenotype");
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByPhenotype_ncraOR74A_phenotype_knockout_mutants_RSRC");

  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }

  
}
