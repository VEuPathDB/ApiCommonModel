package org.apidb.apicommon.model.datasetInjector.custom.AmoebaDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayGilchristStages extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByExpressionTimingPercentileGilchrist"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByEHistolyticaExpressionTiming"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Singh::SinghEhTimeSeries"); 
  }


}

