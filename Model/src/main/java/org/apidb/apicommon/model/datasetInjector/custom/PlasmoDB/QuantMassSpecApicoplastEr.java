package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.ProteinExpressionMassSpec;

public class QuantMassSpecApicoplastEr extends ProteinExpressionMassSpec {

  @Override
  public void addModelReferences() {
    super.addModelReferences();
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                    "GeneQuestions.GenesByProteomics" + getDatasetName());
  }

  @Override
  protected void injectTemplate(String templateName) {
    if (templateName.equals("expressionFoldChangeQuestion")) {
      //Do Nothing
    }
    else {
      super.injectTemplate(templateName);
    }
  }
}
