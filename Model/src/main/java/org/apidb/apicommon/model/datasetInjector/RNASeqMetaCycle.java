package org.apidb.apicommon.model.datasetInjector;

public class RNASeqMetaCycle extends RNASeqEbi {


  @Override
  public void injectTemplates() {

      super.injectTemplates();

      injectTemplate("rnaSeqMetaCycleQuestion");

      //      injectTemplate("rnaSeqMetaCycleParamQuery");

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
