package org.apidb.apicommon.model.datasetInjector.custom.AmoebaDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayGilchristStages extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByExpressionTimingPercentileGilchrist"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByEHistolyticaExpressionTiming"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Singh::SinghEhTimeSeries"); 
  }


}

