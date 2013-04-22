package org.apidb.apicommon.model.datasetInjector.custom.AmoebaDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayGilchristIntestinal extends CusomGenePageExpressionGraphs {

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByExpressionTimingPercentileGilchrist"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByEHistolyticaExpressionTiming"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Gilchrist::GilchristEhTimeSeries"); 
  }


}

