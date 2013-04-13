package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class MicroarrayTwoChannelReferenceDesign extends MicroarrayOneChannelAndReferenceDesign {
  
    public void injectTemplates() {
        super.injectTemplates();

        injectTemplate("microarraySimpleTwoChannelGraph");
    }


    protected void setExprGraphVisiblePart() {
        setPropValue("exprGraphVisiblePart", "expr_val");
    }

    protected void setGraphModule() {
        setPropValue("graphModule", "Microarray::TwoChannel");
    }

    protected void setExprPlotPartModule() {
        setPropValue("exprPlotPartModule", "LogRatio");
    }

}
