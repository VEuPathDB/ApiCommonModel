package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.ExpressionOneChannelAndReferenceDesign;

public class MicroarrayLlinasDecay extends ExpressionOneChannelAndReferenceDesign {

    @Override
    public void injectTemplates() {
        super.injectTemplates();

        injectTemplate("microarrayMRNADecayGraph");
    }

    @Override
    protected void setExprPlotPartModule() {
        setPropValue("exprPlotPartModule", "MRNADecay");
    }

    @Override
    protected void setExprGraphVisiblePart() {
        setPropValue("exprGraphVisiblePart", "exprn_val");
    }

    //    @Override
    //    protected void setGraphsVisibleParts(String visibleParts) {
    //        setPropValue("graphVisibleParts", visibleParts + ",exprn_val_log_ratio"); 
    //    }
 
    @Override
    protected void setGraphModule() {
        setPropValue("graphModule", "Expression");
    }

    @Override
    protected void setProfileSamplesHelp() {
        String profileSamplesHelp = "Normalized Transcript Abundance Values";

        setPropValue("profileSamplesHelp", profileSamplesHelp);
    }

    @Override
    protected void setGraphYAxisDescription() {
        String yAxisDescription = "Normalized Transcript Abundance Values";

        setPropValue("graphYAxisDescription", yAxisDescription);
    }

    @Override
    protected void setDataType() {
        setDataType("Microarray");
    }

    @Override
    protected void setIsLogged() {
        setPropValue("isLogged", "0"); 
    }

    @Override
    public String[][] getPropertiesDeclaration() {
        String[][] exprDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {{"hasPercentileData", ""}, 
        };

        return combinePropertiesDeclarations(exprDeclaration, declaration);
    }


                                   
}
