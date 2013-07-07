package org.apidb.apicommon.model.datasetInjector;


public class MicroarrayOneChannelRma extends MicroarrayOneChannelAndReferenceDesign {

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

}
