package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public abstract class Microarray extends DatasetInjector {

    protected abstract void setExprGraphVisiblePart();
    protected abstract void setGraphModule();
    protected abstract void setExprPlotPartModule();

    public void injectTemplates() {

        // perl packages disallow some characters in the package name... use this to name the graphs
        setGraphDatasetName();

        String projectName = getPropValue("projectName");

        if(getPropValueAsBoolean("isEuPathDBSite")) {
            setPropValue("includeProjects", projectName + ",EuPathDB");
            
        } else {
            setPropValue("includeProjects", projectName);
        }

        injectTemplate("microarrayAttributeCategory");

        setExprGraphVisiblePart();
        setGraphModule();
        setExprPlotPartModule();

        injectTemplate("microarrayGraphAttributes");
    }
    
    public String[][] getPropertiesDeclaration() {
        String [][] declaration = {
                                   {"hasPageData", ""},
                                   {"isEuPathDBSite", ""},
                                   {"graphSampleLabels", "OPTIONAL Prop...provide if you want to override the sample names in the db"},
                                   {"graphColors", "semicolon sep list of colors"},
                                   {"excludedProfileSets", "OPTIONAL PROP... extra profile sets are loaded which we need to exclude from the graphs and questions"},
                                   {"graphBottomMargin", "Optionally override the default bottom margin size"},
                                   {"graphType", "one of bar or line"},
                                   {"graphForceXLabelsHorizontal", "true/false.  NOTE:  Only valid when graphType is bar"},
        };
        
        return declaration;
  }
}

