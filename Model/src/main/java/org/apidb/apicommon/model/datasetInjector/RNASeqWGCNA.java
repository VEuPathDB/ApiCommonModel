package org.apidb.apicommon.model.datasetInjector;

public class RNASeqWGCNA extends RNASeq {


  @Override
  public void injectTemplates() {

      super.injectTemplates();


      setPropValue("searchCategory", "searchCategory-transcriptomics-iterativeWGCNA");
      setPropValue("questionName", "GenesByRNASeqWGCNA" + getDatasetName());

      injectTemplate("internalGeneSearchCategory");

  }



  @Override
  public void addModelReferences() {

      super.addModelReferences();

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GenesByRNASeqWGCNA" + getDatasetName());

  }



}
