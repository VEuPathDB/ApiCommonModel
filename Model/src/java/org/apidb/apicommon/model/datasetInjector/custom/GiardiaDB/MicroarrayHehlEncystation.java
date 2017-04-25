package org.apidb.apicommon.model.datasetInjector.custom.GiardiaDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayHehlEncystation extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GiardiaGenesByExpressionPercentileProfileTwo"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GiardiaGenesByDifferentialExpressionTwo"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GiardiaGenesFoldChangeTwo"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Hehl::Encystation"); 
  }

}

