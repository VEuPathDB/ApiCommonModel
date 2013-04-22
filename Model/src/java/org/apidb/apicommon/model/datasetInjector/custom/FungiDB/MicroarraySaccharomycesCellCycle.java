package org.apidb.apicommon.model.datasetInjector.custom.FungiDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarraySaccharomycesCellCycle extends CusomGenePageExpressionGraphs {

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "SaccharomycesCerevisiae::MicroArrCellCycleTS"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByMicroarrayTimeSeriesSc"); 
  }



}

