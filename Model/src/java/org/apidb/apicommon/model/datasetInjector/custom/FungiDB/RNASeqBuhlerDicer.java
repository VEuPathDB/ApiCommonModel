package org.apidb.apicommon.model.datasetInjector.custom.FungiDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class RNASeqBuhlerDicer extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Spombe972h::RnaSeqDicer"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRnaSeqFoldChangeSpomDicer"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRnaSeqPercentileSpomDicer"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}

