package org.apidb.apicommon.model.datasetInjector;


public abstract class CusomGenePageExpressionGraphsAndCoverage extends CusomGenePageExpressionGraphs {


    @Override
    public void injectTemplates() {
        super.injectTemplates();

        setShortAttribution();

        setOrganismAbbrevFromDatasetName();

        injectTemplate("rnaSeqCoverageTrack");

        String showIntronJunctions = getPropValue("showIntronJunctions");
        if(Boolean.parseBoolean(showIntronJunctions)) {
            injectTemplate("rnaSeqJunctionsTrack");
        }
    }

    @Override
    public String[][] getPropertiesDeclaration() {
        String[][] superDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {{"showIntronJunctions", "should we make junctions track in gbrowse?"},
        };

        return combinePropertiesDeclarations(superDeclaration, declaration);
    }


}
