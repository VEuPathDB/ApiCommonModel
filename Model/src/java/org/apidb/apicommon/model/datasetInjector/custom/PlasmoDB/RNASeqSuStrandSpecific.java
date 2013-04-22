package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class RNASeqSuStrandSpecific extends CusomGenePageExpressionGraphs {

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Su::PfStrandSpecific"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRNASeqSuStrandSpecific"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRNASeqSuStrandSpecificPValue"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRNASeqSuStrandSpecificPercentile"); 
      addWdkReference("SequenceRecordClasses.SequenceRecordClass", "gbrowse_track", "pfal3D7_Su_strand_specific_rnaSeq_RSRC_RNASeqCoverage"); 
  }



}

