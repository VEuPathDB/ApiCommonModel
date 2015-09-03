package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.ExpressionOneChannelAndReferenceDesign;

public class MicroarrayLlinasDecay extends ExpressionOneChannelAndReferenceDesign {

    @Override
    public void injectTemplates() {
        super.injectTemplates();

        injectTemplate("microarrayMRNADecayGraph");
    }

    @Override
    protected void setExprPlotPartModule() {
        setPropValue("exprPlotPartModule", "MRNADecay");
    }

    @Override
    protected void setExprGraphVisiblePart() {
        setPropValue("exprGraphVisiblePart", "exprn_val");
    }

    @Override
    protected void setGraphModule() {
        setPropValue("graphModule", "Expression");
    }

    @Override
    protected void setGraphYAxisDescription() {
        String yAxisDescription = "Normalized Transcript Abudnace Values";

        setPropValue("graphYAxisDescription", yAxisDescription);
    }

    @Override
    protected void setDataType() {
        setDataType("Microarray");
    }

    @Override
    protected void setIsLogged() {
        setPropValue("isLogged", "0"); 
    }

    @Override
    public String[][] getPropertiesDeclaration() {
        String[][] exprDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {{"hasPercentileData", ""},
        };

        return combinePropertiesDeclarations(exprDeclaration, declaration);
    }


                                   
}
