package org.apidb.apicommon.model.datasetInjector.custom.TriTrypDB;

import org.apidb.apicommon.model.datasetInjector.QuantitativeProteomicsNonRatio;

public class QuantProteomicsProcyclicCellCycle extends QuantitativeProteomicsNonRatio {


  @Override
  protected void setIsLogged() {
      setPropValue("isLogged", "0"); 
  }


  @Override
  protected void setExprPlotPartModule() {
      setPropValue("exprPlotPartModule", "QuantMassSpecNonRatioUnlogged");

  }

}


