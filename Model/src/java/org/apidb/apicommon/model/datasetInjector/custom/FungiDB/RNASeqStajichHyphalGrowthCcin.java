package org.apidb.apicommon.model.datasetInjector.custom.FungiDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class RNASeqStajichHyphalGrowthCcin extends CusomGenePageExpressionGraphs {


  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "CcinOk7h130::CcinHyphalGrowthRnaSeq"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRnaSeqFoldChangeCcinHyphalGrowth"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRnaSeqPercentileCcinHyphalGrowth"); 
  }



}
