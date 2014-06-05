package org.apidb.apicommon.model.datasetInjector;


public class MicroarrayTwoChannelDirectComparison extends ExpressionTwoChannelDirectComparison {


    @Override
    public void injectTemplates() {
        super.injectTemplates();

        injectTemplate("microarraySimpleTwoChannelGraph");
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
        setPropValue("graphModule", "Microarray::TwoChannel");
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

    @Override
    public String[][] getPropertiesDeclaration() {
        String[][] exprDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {{"hasPercentileData", ""},
                                   {"redPctSampleMap", "The ProfileElementName will be Like 'A vs B' ... Need to say whether A or B maps to this channel"},
                                   {"greenPctSampleMap", "The ProfileElementName will be Like 'A vs B' ... Need to say whether A or B maps to this channel"},
   
        };

        return combinePropertiesDeclarations(exprDeclaration, declaration);
    }
}
