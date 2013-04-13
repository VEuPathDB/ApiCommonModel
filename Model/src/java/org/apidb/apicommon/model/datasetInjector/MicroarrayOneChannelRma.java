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


}
