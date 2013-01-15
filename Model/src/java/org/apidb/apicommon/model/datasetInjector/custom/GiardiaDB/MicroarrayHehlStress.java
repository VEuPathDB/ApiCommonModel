package org.apidb.apicommon.model.datasetInjector.custom.GiardiaDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class MicroarrayHehlStress extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GiardiaGenesByDifferentialExpression"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GiardiaGenesByExpressionPercentileProfile"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Hehl::Stress1"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Hehl::Stress2"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}

