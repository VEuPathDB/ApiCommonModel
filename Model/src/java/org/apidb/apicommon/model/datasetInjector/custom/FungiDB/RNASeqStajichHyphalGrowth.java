package org.apidb.apicommon.model.datasetInjector.custom.FungiDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class RNASeqStajichHyphalGrowth extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "NeurosporaCrassaOR74A::RnaSeqHyphalGrowth"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRnaSeqFoldChangeNcra"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRnaSeqPercentileNcra"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}

