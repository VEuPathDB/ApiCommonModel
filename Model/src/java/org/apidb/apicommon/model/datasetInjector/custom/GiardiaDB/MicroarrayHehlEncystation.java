package org.apidb.apicommon.model.datasetInjector.custom.GiardiaDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class MicroarrayHehlEncystation extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GiardiaGenesByExpressionPercentileProfileTwo"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GiardiaGenesByDifferentialExpressionTwo"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GiardiaGenesFoldChangeTwo"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Hehl::Encystation"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}

