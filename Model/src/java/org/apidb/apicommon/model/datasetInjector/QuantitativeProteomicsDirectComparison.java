package org.apidb.apicommon.model.datasetInjector;


public class QuantitativeProteomicsDirectComparison extends ExpressionTwoChannelDirectComparison {


    @Override
    public void injectTemplates() {

        // hasPageData required by Expression class but not applicable to Proteomics;  Ensure it is always false
        setPropValue("hasPageData", "false");

        super.injectTemplates();

        //        injectTemplate("microarraySimpleTwoChannelGraph");
    }

    @Override
    protected void setExprPlotPartModule() {
        setPropValue("exprPlotPartModule", "LogRatio");
    }


    @Override
    protected void setExprGraphVisiblePart() {
        setPropValue("exprGraphVisiblePart", "exprn_val");
    }

    @Override
    protected void setGraphModule() {
        setPropValue("graphModule", "TODO::TOTO");
    }


    @Override
    protected void setGraphYAxisDescription() {
        String yAxisDescription = "TODO";

        setPropValue("graphYAxisDescription", yAxisDescription);
    }

    protected void setDataType() {
        setDataType("Proteomics");
    }

    protected void setIsLogged() {
        setPropValue("isLogged", "0"); 
    }

}
