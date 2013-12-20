package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public abstract class CusomGenePageExpressionGraphsAndCoverage extends CusomGenePageExpressionGraphs {


    @Override
    public void injectTemplates() {
        super.injectTemplates();

        setShortAttribution();

        setOrganismAbbrevFromDatasetName();
        setOrganismAbbrevInternalFromDatasetName();

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
