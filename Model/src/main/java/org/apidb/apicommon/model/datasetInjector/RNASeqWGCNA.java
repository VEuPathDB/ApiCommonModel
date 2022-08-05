package org.apidb.apicommon.model.datasetInjector;

public class RNASeqWGCNA extends RNASeq {


  @Override
  public void injectTemplates() {

      super.injectTemplates();


      injectTemplate("rnaSeqWGCNAModulesQuestion");
      setPropValue("searchCategory", "searchCategory-transcriptomics-iterativeWGCNA");
      setPropValue("questionName", "GeneQuestions.GenesByRNASeq" + getDatasetName() + "WGCNAModules");

      injectTemplate("internalGeneSearchCategory");

  }

  
  @Override
  public void addModelReferences() {

      super.addModelReferences();

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRNASeq" + getDatasetName() + "WGCNAModules");
  }


  // The following come from the RNASeqEbi class. Currently our only wgcna datasets are from EBI. In the future if we need
  // more flexibility, consider moving the wgcna-specific code to RNASeq.java with a new flag (something like isWGCNA) and updating datasets
  // in the presenter accordingly.
  @Override
  protected void setProfileSamplesHelp() {
      String profileSamplesHelp = "Transcript abundance in Transcripts per Million (TPM)";
      setPropValue("profileSamplesHelp", profileSamplesHelp);
  }

  @Override
  protected void setExprMetric() {
      setPropValue("exprMetric", "tpm");
  }

  @Override
  protected void setGraphYAxisDescription() {
      setPropValue("graphYAxisDescription", "Transcript abundance in Transcripts per Million (TPM). The percentile graph shows the ranking of expression for this gene compared to all others in this experiment.");
  }



}
