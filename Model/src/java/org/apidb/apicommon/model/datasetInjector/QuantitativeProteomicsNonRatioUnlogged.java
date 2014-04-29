package org.apidb.apicommon.model.datasetInjector;


public class QuantitativeProteomicsNonRatioUnlogged extends QuantitativeProteomicsNonRatio {

    @Override
        protected void setGraphYAxisDescription() {
        String yAxisDescription = "Protein Abundance Values or abundance percentile values";
        
        setPropValue("graphYAxisDescription", yAxisDescription);
    }
    
    @Override
    protected void setExprPlotPartModule() {
        setPropValue("exprPlotPartModule", "QuantMassSpecNonRatioUnlogged");
    }

    @Override
        protected void setIsLogged() {
        setPropValue("isLogged", "0"); 
    }


}

