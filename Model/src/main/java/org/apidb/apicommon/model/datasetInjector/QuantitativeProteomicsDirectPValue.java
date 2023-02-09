package org.apidb.apicommon.model.datasetInjector;


public class QuantitativeProteomicsDirectPValue extends QuantitativeProteomicsDirectComparison {


    @Override
    public void injectTemplates() {

      super.injectTemplates();

      injectTemplate("directComparisonGenericPValueQuestion");
    }


}
