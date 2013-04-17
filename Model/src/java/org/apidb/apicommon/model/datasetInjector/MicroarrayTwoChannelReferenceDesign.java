package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class MicroarrayTwoChannelReferenceDesign extends MicroarrayOneChannelAndReferenceDesign {
  



    public void injectTemplates() {
        super.injectTemplates();

        injectTemplate("microarraySimpleTwoChannelGraph");
    }


    // FOr Microarray Two Channel Ref Design... we want to pick either the red or green percentile profile
    protected void setPercentileProfileFilter() {
        String percentileProfileSetPattern = getPropValue("percentileProfileSetPattern");
        setPropValue("percentileProfileSetPattern", percentileProfileSetPattern);
    }

    protected void setExprGraphVisiblePart() {
        setPropValue("exprGraphVisiblePart", "exprn_val");
    }

    protected void setGraphModule() {
        setPropValue("graphModule", "Microarray::TwoChannel");
    }

    protected void setExprPlotPartModule() {
        setPropValue("exprPlotPartModule", "LogRatio");
    }

    public String[][] getPropertiesDeclaration() {
        String[][] microarrayDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {{"percentileProfileSetPattern", "Which profileset (red/green) has the samples. (ie. not the channel w/ the common reference)."},
        };

        return combinePropertiesDeclarations(microarrayDeclaration, declaration);
    }


    protected void setGraphYAxisDescription() {
        String yAxisDescription = "Expression Values for 2 channel microarray experiments are log ratios (M = log2 Cy5/Cy3).  We also provide the fold difference in the right axis.  For any 2 points on the graph (M1, M2) the  fold difference is calculated by:  power(2, (M2-M1)).   or expression percentile value.";

        setPropValue("graphYAxisDescription", yAxisDescription);
    }


}
