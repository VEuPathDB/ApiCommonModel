package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.QuantitativeProteomicsNonRatio;

public class QuantMassSpecApicoplastEr extends QuantitativeProteomicsNonRatio {


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
