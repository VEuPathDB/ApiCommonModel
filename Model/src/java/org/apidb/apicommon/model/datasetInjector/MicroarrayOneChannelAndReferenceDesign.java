package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public abstract class MicroarrayOneChannelAndReferenceDesign extends Microarray {
  
    public void injectTemplates() {
        super.injectTemplates();

        injectTemplate("microarrayProfileSetParamQuery");
        injectTemplate("microarrayPctProfileSetParamQuery");

        if(getPropValueAsBoolean("hasPageData")) {
            injectTemplate("microarrayFoldChangeWithConfidenceQuestion");
            injectTemplate("microarrayFoldChangeWithConfidenceWS");
        }
            
        injectTemplate("microarrayFoldChangeQuestion");
        injectTemplate("microarrayFoldChangeWS");


        injectTemplate("microarrayPercentileWS");
        injectTemplate("microarrayPercentileQuestion");


        if(getPropValueAsBoolean("hasSimilarityData")) {
            // TODO:  inject ProfileSimilarity Graph
            // TODO:  inject ProfileSimilrity Question
        }

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


        // TODO inject ProfileSimilarity Reference
    }




    public String[][] getPropertiesDeclaration() {
        String[][] microarrayDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {{"isTimeSeries", ""},
                                   //                                   {"hasSimilarityData", ""},
        };

        return combinePropertiesDeclarations(microarrayDeclaration, declaration);
    }







}
