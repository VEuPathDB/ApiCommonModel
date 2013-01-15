package org.apidb.apicommon.model.datasetInjector.custom.GiardiaDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class SageTagsMcArthur extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesBySageTagEvidence"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesBySageTagRStat"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "SageTags"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}

