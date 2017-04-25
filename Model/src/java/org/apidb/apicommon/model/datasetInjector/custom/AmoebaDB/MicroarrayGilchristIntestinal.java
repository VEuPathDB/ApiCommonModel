package org.apidb.apicommon.model.datasetInjector.custom.AmoebaDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayGilchristIntestinal extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByExpressionTimingPercentileGilchrist"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByEHistolyticaExpressionTiming"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Gilchrist::GilchristEhTimeSeries"); 
  }


}

