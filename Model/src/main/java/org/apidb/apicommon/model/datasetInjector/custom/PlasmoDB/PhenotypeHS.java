package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class PhenotypeHS extends DatasetInjector {

  @Override
  public void injectTemplates() {
  }

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByPhenotype_pfal3D7_phenotype_HS_Response_Phenotype_RSRC");

      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "PhenotypeScoreGraphs");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
      String[][] propertiesDeclaration = {};
      return propertiesDeclaration;
  }
  
}
