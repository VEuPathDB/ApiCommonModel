package org.apidb.apicommon.model.datasetInjector;


public class QuantitativeProteomicsDirectComparison extends ExpressionTwoChannelDirectComparison {


    @Override
    public void injectTemplates() {
        // hasPageData required by Expression class but not applicable to Proteomics;  Ensure it is always false
        setPropValue("hasPageData", "false");

        super.injectTemplates();

        injectTemplate("proteomicsSimpleLogRatio");
    }

    @Override
    protected void setExprPlotPartModule() {

        if(getPropValue("isLogged").equals("1")) {
            setPropValue("exprPlotPartModule", "QuantMassSpecLogged");
        }
        else {
            setPropValue("exprPlotPartModule", "QuantMassSpec");
        }
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

    protected void setDataType() {
        setDataType("Proteomics");
    }


    // TODO:  This should be a prop passed in from the xml
    protected void setIsLogged() {
        setPropValue("isLogged", "0"); 
    }

}
