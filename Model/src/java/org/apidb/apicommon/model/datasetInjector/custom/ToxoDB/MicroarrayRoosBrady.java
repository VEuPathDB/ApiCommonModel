package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class MicroarrayRoosBrady extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByTimeSeriesFoldChangeBradyRoos"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByTimeSeriesFoldChangeBradyFl"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByTimeSeriesFoldChangeBradyBoothroyd"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.ToxoGenesByDifferentialMeanExpression"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByTimeSeriesFoldChangeBradyRoosPct"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByTimeSeriesFoldChangeBradyFlPct"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByTimeSeriesFoldChangeBradyBoothroydPct"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.ToxoGenesByDifferentialMeanExpressionPct"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Dzierszinski::TzBz"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Roos::TzBz"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
