package org.apidb.apicommon.model.datasetInjector.custom.GiardiaDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayHehlEncystation extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GiardiaGenesByExpressionPercentileProfileTwo"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GiardiaGenesByDifferentialExpressionTwo"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GiardiaGenesFoldChangeTwo"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Hehl::Encystation"); 
  }

}

