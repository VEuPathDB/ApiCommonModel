package org.apidb.apicommon.model.datasetInjector.custom.GiardiaDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayRingqvistInteraction extends CusomGenePageExpressionGraphs {

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRingqvistFoldChange"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRingqvistPercentile"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Ringqvist::WbClone"); 
  }


}

