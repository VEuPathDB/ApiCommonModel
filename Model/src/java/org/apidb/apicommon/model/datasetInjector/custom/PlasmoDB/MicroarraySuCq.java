package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarraySuCq extends CusomGenePageExpressionGraphs {


  @Override
  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Su::CQTreatment"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesBySuCqFoldChange"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesBySuCqPercentile"); 

      //addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesBySuCqPage"); 
  }


}

