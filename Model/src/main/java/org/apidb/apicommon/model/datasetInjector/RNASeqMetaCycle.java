package org.apidb.apicommon.model.datasetInjector;

public class RNASeqMetaCycle extends RNASeqEbi {


  @Override
  public void injectTemplates() {

      super.injectTemplates();

      injectTemplate("metaCycleQuestion");

      //      injectTemplate("metaCycleParamQuery");

      setPropValue("searchCategory", "searchCategory-transcriptomics-metacycle");
      setPropValue("questionName", "GeneQuestions.GenesByMetaCycle" + getDatasetName());

      injectTemplate("internalGeneSearchCategory");

  }



  @Override
  public void addModelReferences() {

      super.addModelReferences();

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByMetaCycle" + getDatasetName()); 

  }



}
