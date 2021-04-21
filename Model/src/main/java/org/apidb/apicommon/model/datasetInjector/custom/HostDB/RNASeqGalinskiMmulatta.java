package org.apidb.apicommon.model.datasetInjector.custom.HostDB;

import org.apidb.apicommon.model.datasetInjector.RNASeqEbi;

public class RNASeqGalinskiMmulatta extends RNASeqEbi {


  @Override
  public void addModelReferences() {
    super.addModelReferences();
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                    "GeneQuestions.GenesByRNASeq" + getDatasetName());

  }

  @Override
  protected void injectTemplate(String templateName) {
    if (templateName.equals("rnaSeqPercentileQuestion")) {
      //Do Nothing
    }
    else {
      super.injectTemplate(templateName);
    }
  }
}
