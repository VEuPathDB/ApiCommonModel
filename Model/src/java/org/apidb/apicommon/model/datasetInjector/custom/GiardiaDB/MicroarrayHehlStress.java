package org.apidb.apicommon.model.datasetInjector.custom.GiardiaDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayHehlStress extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GiardiaGenesByDifferentialExpression"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GiardiaGenesByExpressionPercentileProfile"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Hehl::Stress1"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Hehl::Stress2"); 
  }

}

