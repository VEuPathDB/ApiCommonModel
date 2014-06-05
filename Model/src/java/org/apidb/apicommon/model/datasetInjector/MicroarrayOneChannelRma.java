package org.apidb.apicommon.model.datasetInjector;


public class MicroarrayOneChannelRma extends ExpressionOneChannelAndReferenceDesign {

    @Override
    public void injectTemplates() {
        super.injectTemplates();

        injectTemplate("microarraySimpleRmaGraph");
    }

    @Override
    protected void setExprPlotPartModule() {
        setPropValue("exprPlotPartModule", "RMA");
    }

    @Override
    protected void setExprGraphVisiblePart() {
        setPropValue("exprGraphVisiblePart", "rma");
    }

    @Override
    protected void setGraphModule() {
        setPropValue("graphModule", "Microarray::RMA");
    }

    @Override
    protected void setGraphYAxisDescription() {
        String yAxisDescription = "RMA Normalized Values (log base 2) or expression percentile value.";

        setPropValue("graphYAxisDescription", yAxisDescription);
    }

    @Override
    protected void setDataType() {
        setDataType("Microarray");
    }

    @Override
    public String[][] getPropertiesDeclaration() {
        String[][] exprDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {{"hasPercentileData", ""},
        };

        return combinePropertiesDeclarations(exprDeclaration, declaration);
    }
}
