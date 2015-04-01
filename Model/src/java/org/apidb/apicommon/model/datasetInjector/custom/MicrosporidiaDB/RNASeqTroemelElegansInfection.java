package org.apidb.apicommon.model.datasetInjector.custom.MicrosporidiaDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphsAndCoverage;

public class RNASeqTroemelElegansInfection extends CusomGenePageExpressionGraphsAndCoverage {


  @Override
  public void addModelReferences() {
    addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Troemel::CelegansInfectionTimeSeries");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRNASeqTroemelCeInfectionFC");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRNASeqTroemelCeInfectionPercentile");
  }
}
