package org.apidb.apicommon.model.datasetInjector;


public abstract class ExpressionOneChannelAndReferenceDesign extends Expression {

    @Override
    public void injectTemplates() {
        super.injectTemplates();

        String lcDataType = getPropValue("dataType").toLowerCase();

        String decodeProfileSet = makeDecodeMappingStrings(getPropValue("profileSetNameMap"));
        setPropValue("decodeProfileSet", decodeProfileSet);

        setPercentileProfileFilter();

        injectTemplate("expressionProfileSetParamQuery");
        injectTemplate("expressionPctProfileSetParamQuery");

        if(getPropValueAsBoolean("hasPageData")) {
            injectTemplate("expressionFoldChangeWithConfidenceQuestion");
            injectTemplate(lcDataType + "FoldChangeWithConfidenceWS");
        }
            
        injectTemplate("expressionFoldChangeQuestion");
        injectTemplate(lcDataType + "FoldChangeWS");

        if(getPropValueAsBoolean("hasPercentileData")) {
            injectTemplate("expressionPercentileQuestion");
            injectTemplate(lcDataType + "PercentileWS");
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

        String dataType = getDataType();

        if(getPropValueAsBoolean("hasPageData")) {
            addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                            "GeneQuestions.GenesBy" + dataType + getDatasetName() + "Confidence");
        }
        addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                        "GeneQuestions.GenesBy" + dataType + getDatasetName());

        if(getPropValueAsBoolean("hasPercentileData")) {
            addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                            "GeneQuestions.GenesBy" + dataType + getDatasetName() + "Percentile");
        }

        // TODO inject ProfileSimilarity Reference
    }




    @Override
    public String[][] getPropertiesDeclaration() {
        String[][] exprDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {
                                   {"profileSetNameMap", "Optionally replace profileset names"},
                                   //                                   {"hasSimilarityData", ""},
        };

        return combinePropertiesDeclarations(exprDeclaration, declaration);
    }







}
