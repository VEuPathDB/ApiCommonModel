package org.apidb.apicommon.model.datasetInjector.custom.FungiDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarraySaccharomycesCellCycle extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "SaccharomycesCerevisiae::MicroArrCellCycleTS"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByMicroarrayTimeSeriesSc"); 
  }



}

