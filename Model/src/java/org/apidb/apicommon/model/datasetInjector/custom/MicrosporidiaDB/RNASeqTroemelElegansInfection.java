package org.apidb.apicommon.model.datasetInjector.custom.MicrosporidiaDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphsAndCoverage;

public class RNASeqTroemelElegansInfection extends CusomGenePageExpressionGraphsAndCoverage {


  @Override
  public void addModelReferences() {
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Troemel::CelegansInfectionTimeSeries");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRNASeqTroemelCeInfectionFC");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRNASeqTroemelCeInfectionPercentile");
  }
}
