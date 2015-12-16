package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphsAndCoverage;

public class RNASeqCaroRibosome extends CusomGenePageExpressionGraphsAndCoverage {


  @Override
  public void addModelReferences() {
    addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Caro::Ribosome");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRNASeqpfal3D7_Caro_ribosome_profiling_rnaSeq_RSRC");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRNASeqpfal3D7_Caro_ribosome_profiling_rnaSeq_RSRCPValue");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRNASeqpfal3D7_Caro_ribosome_profiling_rnaSeq_RSRCPercentile");
  }
}
