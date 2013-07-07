package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayCowmanSir2 extends CusomGenePageExpressionGraphs {


  @Override
  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Cowman::Sir2KO"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Cowman::Ver2"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByCowmanSir2FoldChange"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByCowmanSir2Percentile"); 
  }


}
