package org.apidb.apicommon.model.datasetInjector.custom.HostDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class RNASeqME49PostInfection extends CusomGenePageExpressionGraphs {


  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Gregory::TgME49RnaSeqHuman"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRNASeqTgME49HumanFoldChange"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRNASeqTgME49HumanPercentile"); 
  }



}

