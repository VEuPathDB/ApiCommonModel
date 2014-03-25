package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayFerdigEQtl extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Ferdig::Dd2Hb3Similarity"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Ferdig::DD2_X_HB3"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByEqtlProfileSimilarity"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByEQTL_HaploGrpSimilarity"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByEQTL_Segments"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "Plasmo_eQTL_Table"); 
      addWdkReference("SpanRecordClasses.SpanRecordClass", "question", "SpanQuestions.DynSpansByEQTLtoGenes"); 
  }


}

