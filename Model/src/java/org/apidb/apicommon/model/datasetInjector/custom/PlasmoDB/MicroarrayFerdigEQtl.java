package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class MicroarrayFerdigEQtl extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Ferdig::Dd2Hb3Similarity"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Ferdig::DD2_X_HB3"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByEqtlProfileSimilarity"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByEQTL_HaploGrpSimilarity"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByEQTL_Segments"); 
      addWdkReference("SpanRecordClasses.SpanRecordClass", "question", "SpanQuestions.DynSpansByEQTLtoGenes"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}

