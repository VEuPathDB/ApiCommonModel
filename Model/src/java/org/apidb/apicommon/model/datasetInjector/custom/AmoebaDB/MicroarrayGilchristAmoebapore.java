package org.apidb.apicommon.model.datasetInjector.custom.AmoebaDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayGilchristAmoebapore extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByExpressionPercentileGilchrist"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByAmoebaFoldChangeGilchrist"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByAmoebaFoldChangePageGilchrist"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Gilchrist::EhG3Hm1Imss"); 
  }


}

