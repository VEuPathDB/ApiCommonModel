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
        setPropValue("isLogged", "1"); 
    }



    @Override
        public String[][] getPropertiesDeclaration() {
        String[][] exprDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {{"isLogged", "Is the Data Logged or not"},
        };
        
        return combinePropertiesDeclarations(exprDeclaration, declaration);
    }
}

