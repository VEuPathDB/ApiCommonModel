package org.apidb.apicommon.model.datasetInjector.custom.GiardiaDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayHehlStress extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GiardiaGenesByDifferentialExpression"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GiardiaGenesByExpressionPercentileProfile"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Hehl::Stress1"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Hehl::Stress2"); 
  }

}

