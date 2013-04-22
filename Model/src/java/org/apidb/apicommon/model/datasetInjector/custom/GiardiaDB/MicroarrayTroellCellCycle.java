package org.apidb.apicommon.model.datasetInjector.custom.GiardiaDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayTroellCellCycle  extends CusomGenePageExpressionGraphs {

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByPercentileTroellCC"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesbyFoldChangeTroellCC"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Troell::CellCycle"); 
  }



}

