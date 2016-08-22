package org.apidb.apicommon.model.datasetInjector;

import java.util.List;

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

          String datasetName = getDatasetName();        
          String experimentName = datasetName.replace("_rnaSeq_RSRC", "");
          

          //String experimentName = experimentRsrc.replaceFirst("RSRC", "");
          setPropValue("experimentName", experimentName);

          // String organismAbbrev = getPropValue("organismAbbrev");

          List<String> sampleNames = getSampleList();
          String subtracks = "";
          for (int i=0; i<sampleNames.size(); i++) {
              String subtrack = sampleNames.get(i);
              if (i == sampleNames.size() -1) {
                  subtracks = subtracks + "'" + subtrack + "';";
              }
              else {
                  subtracks = subtracks + "'" + subtrack + "';\n                  ";
              }
          }
          setPropValue("subtracks", subtracks);

          if(projectName.equals("HostDB")) {
              setPropValue("intronSizeLimit", "50000");
          }
          else {
              setPropValue("intronSizeLimit", "5000");
          }
          setPropValue("subtracks", subtracks);

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
