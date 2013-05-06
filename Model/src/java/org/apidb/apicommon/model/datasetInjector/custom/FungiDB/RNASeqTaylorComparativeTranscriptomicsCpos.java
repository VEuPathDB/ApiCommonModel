package org.apidb.apicommon.model.datasetInjector.custom.FungiDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class RNASeqTaylorComparativeTranscriptomicsCpos extends CusomGenePageExpressionGraphs {


  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "CposC735::CposComTranRnaSeq"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRnaSeqFoldChangeCposComTran"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRnaSeqPercentileCposComTran"); 
  }



}
