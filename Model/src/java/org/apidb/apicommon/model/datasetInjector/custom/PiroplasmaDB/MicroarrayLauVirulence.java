package org.apidb.apicommon.model.datasetInjector.custom.PiroplasmaDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class MicroarrayLauVirulence extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Lau::Bbovis"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByLauBbovisFoldChange"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByLauBbovisPercentile"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByLauBbovisPaGE"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
