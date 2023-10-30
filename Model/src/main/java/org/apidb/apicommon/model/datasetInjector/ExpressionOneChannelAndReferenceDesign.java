package org.apidb.apicommon.model.datasetInjector;


public abstract class ExpressionOneChannelAndReferenceDesign extends Expression {

    @Override
    public void injectTemplates() {
        super.injectTemplates();

        String lcDataType = getPropValue("dataType").toLowerCase();

        String decodeProfileSet = makeDecodeMappingStrings(getPropValue("profileSetNameMap"));
        setPropValue("decodeProfileSet", decodeProfileSet);

        setPercentileProfileFilter();

        setPropValue("defaultFoldDifference","2.0"); 
        if(lcDataType.equals("proteomics")) {
            setPropValue("defaultFoldDifference","1.5");
        }
        injectTemplate("expressionProfileSetParamQuery");
        injectTemplate("expressionPctProfileSetParamQuery");

        if(getPropValueAsBoolean("hasMultipleSamples")) {

	    /**
            if(getPropValueAsBoolean("hasPageData")) {
                injectTemplate("expressionFoldChangeWithConfidenceQuestion");
                //                injectTemplate(lcDataType + "FoldChangeWithConfidenceCategories");

                setPropValue("searchCategory", "searchCategory-" + getSearchCategoryType() +"-fold-change-with-confidence");
                setPropValue("questionName", "GeneQuestions.GenesBy" + getDataType() + getDatasetName() + "Confidence");
                injectTemplate("internalGeneSearchCategory");

            }
	    **/

	    setPropValue("dynColSuffix","");
	    setPropValue("datasetFloor","0.01");
	    setPropValue("floorText","Any values less than the floor of 0.01 are raised to 0.01 to compute the fold difference."); 
	    if(getPropValue("isLogged").equals("1")) {
		setPropValue("dynColSuffix"," (log2)");
		setPropValue("datasetFloor","0");
		setPropValue("floorText","");
	    }

            injectTemplate("expressionFoldChangeQuestion");
            //            injectTemplate(lcDataType + "FoldChangeCategories");
            setPropValue("searchCategory", "searchCategory-" + getSearchCategoryType() +"-fold-change");
            setPropValue("questionName", "GeneQuestions.GenesBy" + getDataType() + getDatasetName());
            injectTemplate("internalGeneSearchCategory");

        }

        if(getPropValueAsBoolean("hasPercentileData")) {
            injectTemplate("expressionPercentileQuestion");
            //            injectTemplate(lcDataType + "PercentileCategories");
            setPropValue("searchCategory", "searchCategory-" + getSearchCategoryType() +"-percentile");
            setPropValue("questionName", "GeneQuestions.GenesBy" + getDataType() + getDatasetName() + "Percentile");
            injectTemplate("internalGeneSearchCategory");

        }

        if(getPropValueAsBoolean("hasSimilarityData")) {
            // TODO:  inject ProfileSimilarity Graph
            // TODO:  inject ProfileSimilrity Question
        }

    }

    protected void setPercentileProfileFilter() {
        setPropValue("percentileChannelPattern", "%");
    }

    @Override
    public void addModelReferences() {
	super.addModelReferences();

        setDataType();
        String myDataType = getDataType();


        if(getPropValueAsBoolean("hasMultipleSamples")) {

	    /**
            if(getPropValueAsBoolean("hasPageData")) {
                addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                                "GeneQuestions.GenesBy" + myDataType + getDatasetName() + "Confidence");
            }
	    **/

            addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                            "GeneQuestions.GenesBy" + myDataType + getDatasetName());
        }

        if(getPropValueAsBoolean("hasPercentileData")) {
            addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                            "GeneQuestions.GenesBy" + myDataType + getDatasetName() + "Percentile");
        }

        // TODO inject ProfileSimilarity Reference
    }




    @Override
    public String[][] getPropertiesDeclaration() {
        String[][] exprDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {
                                   {"hasMultipleSamples", ""},
                                   //                                   {"hasSimilarityData", ""},
        };

        return combinePropertiesDeclarations(exprDeclaration, declaration);
    }







}
