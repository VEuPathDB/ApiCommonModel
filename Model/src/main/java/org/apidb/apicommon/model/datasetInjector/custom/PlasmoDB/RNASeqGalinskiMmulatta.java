package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.RNASeqEbi;

public class RNASeqGalinskiMmulatta extends RNASeqEbi {

  @Override
  public void addModelReferences() {
    super.addModelReferences();
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                    "GeneQuestions.GenesByRNASeq" + getDatasetName());
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                    "GeneQuestions.GenesByRNASeq" + getDatasetName() + "SenseAntisense");
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
