package org.apidb.apicommon.model.datasetInjector;


public class QuantitativeProteomicsReferenceDesign extends ExpressionOneChannelAndReferenceDesign {

    @Override
    public void injectTemplates() {
        super.injectTemplates();

        injectTemplate("proteomicsSimpleLogRatio");
    }

    @Override
    protected void setExprPlotPartModule() {
        setPropValue("exprPlotPartModule", "QuantMassSpecLogRatio");
    }

    @Override
    protected void setExprGraphVisiblePart() {
        setPropValue("exprGraphVisiblePart", "exprn_val");
    }

    @Override
    protected void setGraphModule() {
        setPropValue("graphModule", "Proteomics::LogRatio");
    }

    @Override
    protected void setGraphYAxisDescription() {
        String yAxisDescription = "TODO";

        setPropValue("graphYAxisDescription", yAxisDescription);
    }

    @Override
    protected void setDataType() {
        setDataType("Proteomics");
    }

    @Override
    /**
     *  Override from superclass... do nothing because we get this from the prop Declaration
     */
    protected void setIsLogged() {}

    @Override
    public String[][] getPropertiesDeclaration() {
        String[][] exprDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {{"isLogged", "Is the Data Logged or not"},
        };

        return combinePropertiesDeclarations(exprDeclaration, declaration);
    }

}
