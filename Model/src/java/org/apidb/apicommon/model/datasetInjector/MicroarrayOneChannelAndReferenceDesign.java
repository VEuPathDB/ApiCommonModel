package org.apidb.apicommon.model.datasetInjector;


public abstract class MicroarrayOneChannelAndReferenceDesign extends Microarray {

    @Override
    public void injectTemplates() {
        super.injectTemplates();

        String decodeProfileSet = makeDecodeMappingStrings(getPropValue("profileSetNameMap"));
        setPropValue("decodeProfileSet", decodeProfileSet);

        setPercentileProfileFilter();

        injectTemplate("expressionProfileSetParamQuery");
        injectTemplate("expressionPctProfileSetParamQuery");

        if(getPropValueAsBoolean("hasPageData")) {
            injectTemplate("expressionFoldChangeWithConfidenceQuestion");
            injectTemplate("microarrayFoldChangeWithConfidenceWS");
        }
            
        injectTemplate("expressionFoldChangeQuestion");
        injectTemplate("microarrayFoldChangeWS");

        if(getPropValueAsBoolean("hasPercentileData")) {
            injectTemplate("expressionPercentileQuestion");
            injectTemplate("microarrayPercentileWS");
        }

        if(getPropValueAsBoolean("hasSimilarityData")) {
            // TODO:  inject ProfileSimilarity Graph
            // TODO:  inject ProfileSimilrity Question
        }

    }

    protected void setPercentileProfileFilter() {
        setPropValue("percentileProfileSetPattern", "%");
    }

    @Override
    public void addModelReferences() {
	super.addModelReferences();

        if(getPropValueAsBoolean("hasPageData")) {
            addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                            "GeneQuestions.GenesByMicroarray" + getDatasetName() + "Confidence");
        }
        addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                        "GeneQuestions.GenesByMicroarray" + getDatasetName());

        if(getPropValueAsBoolean("hasPercentileData")) {
            addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                            "GeneQuestions.GenesByMicroarray" + getDatasetName() + "Percentile");
        }

        // TODO inject ProfileSimilarity Reference
    }




    @Override
    public String[][] getPropertiesDeclaration() {
        String[][] microarrayDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {
                                   {"profileSetNameMap", "Optionally replace profileset names"},
                                   //                                   {"hasSimilarityData", ""},
        };

        return combinePropertiesDeclarations(microarrayDeclaration, declaration);
    }







}
