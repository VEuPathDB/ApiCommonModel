package org.apidb.apicommon.model.datasetInjector;

public class RNASeqWGCNA extends RNASeq {


  @Override
  public void injectTemplates() {

      super.injectTemplates();


      setPropValue("searchCategory", "searchCategory-transcriptomics-iterativeWGCNA");
      setPropValue("questionName", "GenesByRNASeqWGCNApfal3D7_Lee_Gambian_rnaSeq_RSRC");

      injectTemplate("internalGeneSearchCategory");

  }



  @Override
  public void addModelReferences() {

      super.addModelReferences();

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GenesByRNASeqWGCNApfal3D7_Lee_Gambian_rnaSeq_RSRC");

  }



}
