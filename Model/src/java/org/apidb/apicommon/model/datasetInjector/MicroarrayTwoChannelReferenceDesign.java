package org.apidb.apicommon.model.datasetInjector;


public class MicroarrayTwoChannelReferenceDesign extends ExpressionOneChannelAndReferenceDesign {

    @Override  
    public void injectTemplates() {
        super.injectTemplates();

        injectTemplate("microarraySimpleTwoChannelGraph");
    }

    // FOr Microarray Two Channel Ref Design... we want to pick either the red or green percentile profile
    @Override
    protected void setPercentileProfileFilter() {
        String percentileChannelPattern = getPropValue("percentileChannelPattern");
        setPropValue("percentileChannelPattern", percentileChannelPattern);
    }

    @Override
    protected void setExprGraphVisiblePart() {
        setPropValue("exprGraphVisiblePart", "exprn_val");
    }

    @Override
    protected void setGraphModule() {
        setPropValue("graphModule", "ExpressionTwoChannel");
    }

    @Override
    protected void setExprPlotPartModule() {
        setPropValue("exprPlotPartModule", "LogRatio");
    }

    @Override
    public String[][] getPropertiesDeclaration() {
        String[][] microarrayDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {{"percentileChannelPattern", "Which profileset (red/green) has the samples. (ie. not the channel w/ the common reference)."},
                                   {"hasPercentileData", ""},
        };
        return combinePropertiesDeclarations(microarrayDeclaration, declaration);
    }

    @Override
    protected void setGraphYAxisDescription() {
        String yAxisDescription = "Expression Values for 2 channel microarray experiments are log ratios (M = log2 Cy5/Cy3).  We also provide the fold difference in the right axis.  For any 2 points on the graph (M1, M2) the  fold difference is calculated by:  power(2, (M2-M1)).   or expression percentile value.";

        setPropValue("graphYAxisDescription", yAxisDescription);
    }

    @Override
    protected void setDataType() {
        setDataType("Microarray");
    }

}
