package org.apidb.apicommon.model.datasetInjector;


public class MicroarrayOneChannelQuantile extends ExpressionOneChannelAndReferenceDesign {

    @Override
    public void injectTemplates() {
        super.injectTemplates();

        injectTemplate("microarraySimpleQuantileGraph");
    }

    @Override
    protected void setExprPlotPartModule() {
        setPropValue("exprPlotPartModule", "QuantileNormalized");
    }

    @Override
    protected void setExprGraphVisiblePart() {
        setPropValue("exprGraphVisiblePart", "exprn_val");
    }

    @Override
    protected void setGraphModule() {
        setPropValue("graphModule", "Microarray::Quantile");
    }

    @Override
    protected void setGraphYAxisDescription() {
        String yAxisDescription = "Quantile Normalized Values (log base 2) or expression percentile value.";

        setPropValue("graphYAxisDescription", yAxisDescription);
    }

    protected void setDataType() {
        setDataType("Microarray");
    }


}
