package org.apidb.apicommon.model.datasetInjector.custom.FungiDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class RNASeqStajichHyphalGrowthRory extends CusomGenePageExpressionGraphs {


  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Rory99880::RoryHyphalGrowthRnaSeq"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRnaSeqFoldChangeRoryHyphalGrowth"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRnaSeqPercentileRoryHyphalGrowth"); 
  }



}
