package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.QuantitativeProteomicsNonRatio;

public class QuantMassSpecApicoplastEr extends QuantitativeProteomicsNonRatio {


  @Override
  protected void injectTemplate(String templateName) {
      setPropValue("datasetFloor","0.0000001");
      setPropValue("defaultFoldDifference","0.7");
      super.injectTemplate(templateName);
  }
}
