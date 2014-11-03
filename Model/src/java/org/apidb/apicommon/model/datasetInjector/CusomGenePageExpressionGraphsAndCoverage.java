package org.apidb.apicommon.model.datasetInjector;


public abstract class CusomGenePageExpressionGraphsAndCoverage extends CusomGenePageExpressionGraphs {


    @Override
    public void injectTemplates() {
        super.injectTemplates();

        setShortAttribution();

        String projectName = getPropValue("projectName");

        setOrganismAbbrevFromDatasetName();

        injectTemplate("rnaSeqCoverageTrack");
        injectTemplate("rnaSeqCoverageTrackUnlogged");

        String showIntronJunctions = getPropValue("showIntronJunctions");
        if(Boolean.parseBoolean(showIntronJunctions)) {

            if(projectName.equals("HostDB")) {
              setPropValue("intronSizeLimit", "50000");
            } else {
              setPropValue("intronSizeLimit", "5000");
            }

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
