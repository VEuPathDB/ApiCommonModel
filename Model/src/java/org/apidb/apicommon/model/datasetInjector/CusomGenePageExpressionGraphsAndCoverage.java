package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public abstract class CusomGenePageExpressionGraphsAndCoverage extends CusomGenePageExpressionGraphs {


    public void injectTemplates() {
        super.injectTemplates();

        setShortAttribution();

        setOrganismAbbrevFromDatasetName();
        setOrganismAbbrevInternalFromDatasetName();

        injectTemplate("rnaSeqCoverageTrack");

        String hasJunctions = getPropValue("hasJunctions");
        if(Boolean.parseBoolean(hasJunctions)) {
            injectTemplate("rnaSeqJunctionsTrack");
        }
    }


    public String[][] getPropertiesDeclaration() {
        String[][] superDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {{"hasJunctions", "should we make junctions track in gbrowse?"},
        };

        return combinePropertiesDeclarations(superDeclaration, declaration);
    }


}
