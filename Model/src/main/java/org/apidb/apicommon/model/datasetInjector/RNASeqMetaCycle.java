package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.model.datasetInjector.RNASeq;
public class RNASeqMetaCycle extends RNASeq {


  @Override
  public void injectTemplates() {

      super.injectTemplates();

      injectTemplate("rnaSeqMetaCycleQuestion");
      injectTemplate("rnaSeqMetaCycleParamQuery");

      setPropValue("searchCategory", "searchCategory-transcriptomics-metacycle");
      setPropValue("questionName", "GeneQuestions.GenesByRNASeqMetaCycle" + getDatasetName());

      injectTemplate("internalGeneSearchCategory");

  }



  @Override
  public void addModelReferences() {

      super.addModelReferences();

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRNASeqMetaCycle" + getDatasetName()); 

  }



}
