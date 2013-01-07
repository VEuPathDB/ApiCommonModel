package org.apidb.apicommon.model.datasetInjector.custom.FungiDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class MicroarraySaccharomycesCellCycle extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "SaccharomycesCerevisiae::MicroArrCellCycleTS"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByMicroarrayTimeSeriesSc"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}

