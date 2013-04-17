package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class MicroarrayOneChannelRma extends MicroarrayOneChannelAndReferenceDesign {
  
    public void injectTemplates() {
        super.injectTemplates();

        injectTemplate("microarraySimpleRmaGraph");
    }

    protected void setExprPlotPartModule() {
        setPropValue("exprPlotPartModule", "RMA");
    }

    protected void setExprGraphVisiblePart() {
        setPropValue("exprGraphVisiblePart", "rma");
    }

    protected void setGraphModule() {
        setPropValue("graphModule", "Microarray::RMA");
    }

    protected void setGraphYAxisDescription() {
        String yAxisDescription = "RMA Normalized Values (log base 2) or expression percentile value.";

        setPropValue("graphYAxisDescription", yAxisDescription);
    }

}
