package org.apidb.apicommon.model.datasetInjector.custom.AmoebaDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayGilchristAmoebapore extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByExpressionPercentileGilchrist"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByAmoebaFoldChangeGilchrist"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByAmoebaFoldChangePageGilchrist"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Gilchrist::EhG3Hm1Imss"); 
  }


}

