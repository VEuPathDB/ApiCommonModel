package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class MicroarrayOneChannelQuantile extends MicroarrayOneChannelAndReferenceDesign {
  
    public void injectTemplates() {
        super.injectTemplates();

        injectTemplate("microarraySimpleQuantileGraph");
    }

    protected void setExprPlotPartModule() {
        setPropValue("exprPlotPartModule", "QuantileNormalized");
    }

    protected void setExprGraphVisiblePart() {
        setPropValue("exprGraphVisiblePart", "exprn_val");
    }

    protected void setGraphModule() {
        setPropValue("graphModule", "Microarray::Quantile");
    }

    protected void setGraphYAxisDescription() {
        String yAxisDescription = "Quantile Normalized Values (log base 2) or expression percentile value.";

        setPropValue("graphYAxisDescription", yAxisDescription);
    }

}
