package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public abstract class Microarray extends DatasetInjector {
  
    protected abstract void setDecodePercentileProp();

    public void injectTemplates() {
        String organismAbbrev = getOrganismAbbrevFromDatasetName();
        setPropValue("organismAbbrev", organismAbbrev);

        String projectName = getPropValue("projectName");

        if(getPropValueAsBoolean("isEuPathDBSite")) {
            setPropValue("includeProjects", projectName + ",EuPathDB");
            
        } else {
            setPropValue("includeProjects", projectName);
        }

        // param queries can be shared
        //  but may need special profile set name mapping
        setDecodePercentileProp();

        injectTemplate("microarrayAttributeCategory");
        injectTemplate("microarrayProfileSetParamQuery");
        injectTemplate("microarrayPctProfileSetParamQuery");


        if(getPropValueAsBoolean("hasSimilarityData")) {
            // TODO:  inject ProfileSimilarity Graph
            // TODO:  inject ProfileSimilrity Question
        }

        if(getPropValueAsBoolean("hasPageData")) {
            injectTemplate("microarrayFoldChangeWithConfidenceQuestion");
            injectTemplate("microarrayFoldChangeWithConfidenceWS");
        }
        
        injectTemplate("microarrayFoldChangeQuestion");
        injectTemplate("microarrayFoldChangeWS");

        injectTemplate("microarrayPercentileWS");
        injectTemplate("microarrayPercentileQuestion");
    }
    
    public void addModelReferences() {

        if(getPropValueAsBoolean("hasPageData")) {
            addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                            "GenesByMicroarray" + getDatasetName() + "Confidence");
        }
        addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                        "GenesByMicroarray" + getDatasetName());
        addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                        "GenesByMicroarray" + getDatasetName() + "Percentile");
    }

    
    // declare properties required beyond those inherited from the datasetPresenter
    // second column is for documentation
    public String[][] getPropertiesDeclaration() {
        String [][] declaration = {{"isTimeSeries", ""},
                                   {"hasPageData", ""},
                                   //                                   {"hasSimilarityData", ""}, // need to add special graph for this
                                   {"isEuPathDBSite", ""},
        };
        
        return declaration;
  }
}
