package org.apidb.apicommon.model.datasetInjector.custom.FungiDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class RNASeqHyaarInfection extends CusomGenePageExpressionGraphs {


  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "HyaarEmoy2::RnaSeqInfection"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRnaSeqPercentileHyaarInfection"); 
  }



}
