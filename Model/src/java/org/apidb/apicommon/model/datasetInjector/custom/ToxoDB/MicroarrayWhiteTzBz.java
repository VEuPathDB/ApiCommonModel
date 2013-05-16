package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayWhiteTzBz extends CusomGenePageExpressionGraphs {


  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "White::TzBz"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.ToxoGenesByDifferentialMeanExpression"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.ToxoGenesByDifferentialMeanExpressionPct");
  }



}