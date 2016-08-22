package org.apidb.apicommon.model.datasetInjector.custom.GiardiaDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class RNASeqSvard3Strains extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRNASeqSvard3StagesFC"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRNASeqSvard3StagesPercentile"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Svard::RNASeqThreeStrains"); 
  }



}

