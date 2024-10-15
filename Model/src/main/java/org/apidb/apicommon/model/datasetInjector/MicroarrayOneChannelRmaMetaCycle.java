package org.apidb.apicommon.model.datasetInjector;

public class MicroarrayOneChannelRmaMetaCycle extends MicroarrayOneChannelRma {


  @Override
  public void injectTemplates() {

      super.injectTemplates();

      setPropValue("searchCategory", "searchCategory-transcriptomics-metacycle");

      injectTemplate("internalGeneSearchCategory");

  }



  @Override
  public void addModelReferences() {

      super.addModelReferences();

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByMicroarrayMetaCycle" + getDatasetName()); 

  }



}
