
package org.apidb.apicommon.model.datasetInjector;


public abstract class ExpressionTwoChannelDirectComparison extends Expression {

    @Override
    public void injectTemplates() {
        super.injectTemplates();

        setPropValue("decodeProfileSet", "");
        setPropValue("percentileChannelPattern", "%");

        injectTemplate("expressionProfileSetParamQuery");
        setPropValue("defaultFoldDifference","2.0"); 

        String lcDataType = getPropValue("dataType").toLowerCase();

	if((getPropValueAsBoolean("hasPercentileData"))  && !(lcDataType.equals("proteomics"))) {
	    String channelOnePctSampleDecode = makeDecodeMappingStrings(getPropValue("channelOnePctSampleMap"));
	    String channelTwoPctSampleDecode = makeDecodeMappingStrings(getPropValue("channelTwoPctSampleMap"));
                
	    setPropValue("channelOnePctSampleDecode", channelOnePctSampleDecode);
	    setPropValue("channelTwoPctSampleDecode", channelTwoPctSampleDecode);
	}

        if(lcDataType.equals("proteomics")) { 
            setPropValue("defaultFoldDifference","1.5");
                
        }
        //        if(getPropValueAsBoolean("hasPageData") && lcDataType.equals("proteomics")) {
        //            injectTemplate("expressionSamplesParamQueryDirectFDR");
        //        } 
        //        else {
            injectTemplate("expressionSamplesParamQueryDirect");
            //        }

            /**
        if(getPropValueAsBoolean("hasPageData") && lcDataType.equals("proteomics")) {
            injectTemplate("expressionFoldChangeWithFDRQuestionDirect");
            //            injectTemplate(lcDataType + "FoldChangeWithFDRCategoriesDirect");
            setPropValue("searchCategory", "searchCategory-" + getSearchCategoryType() +"-fold-change-with-fdr");
            setPropValue("questionName", "GeneQuestions.GenesBy" + getDataType() + "DirectWithFDR" + getDatasetName());
            injectTemplate("internalGeneSearchCategory");
        } 

            **/

        if (getPropValueAsBoolean("hasPageData") && !(lcDataType.equals("proteomics"))) {
            injectTemplate("PageProfileSetParamQuery");
            injectTemplate("expressionFoldChangeWithConfidenceQuestionDirect");
            //            injectTemplate(lcDataType + "FoldChangeWithConfidenceCategoriesDirect");
            setPropValue("searchCategory", "searchCategory-" + getSearchCategoryType() +"-direct-comparison");
            setPropValue("questionName", "GeneQuestions.GenesBy" + getDataType() + "DirectWithConfidence" + getDatasetName());
            injectTemplate("internalGeneSearchCategory");

        } 

        else {

            injectTemplate("expressionFoldChangeQuestionDirect");

            //injectTemplate(lcDataType + "FoldChangeCategoriesDirect");
            setPropValue("searchCategory", "searchCategory-" + getSearchCategoryType() +"-direct-comparison");
            setPropValue("questionName", "GeneQuestions.GenesBy" + getDataType() + "Direct" + getDatasetName());
            injectTemplate("internalGeneSearchCategory");
        }

        if(getPropValueAsBoolean("hasPercentileData")) {
	    setPropValue("searchCategory", "searchCategory-" + getSearchCategoryType() +"-percentile");


	    if (lcDataType.equals("proteomics")) {
		injectTemplate("expressionPercentileQuestion");
		//  injectTemplate(lcDataType + "PercentileCategories");
		setPropValue("questionName", "GeneQuestions.GenesBy" + getDataType() + getDatasetName() + "Percentile");
	    } else {
		injectTemplate("expressionPctSamplesParamQueryDirect");
		injectTemplate("expressionPctProfileSetParamQuery");

		// injectTemplate(lcDataType + "PercentileCategoriesDirect");
		setPropValue("questionName", "GeneQuestions.GenesBy" + getDataType() + "Direct" + getDatasetName() + "Percentile");
		injectTemplate("expressionPercentileQuestionDirect");
	    }
	    injectTemplate("internalGeneSearchCategory");
        }

    }



    @Override
    public void addModelReferences() {
	super.addModelReferences();

        setDataType();

        String myDataType = getDataType();

        /**
        if(getPropValueAsBoolean("hasPageData") && myDataType.equals("Proteomics")) {
            addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                            "GeneQuestions.GenesBy" + myDataType + "DirectWithFDR" + getDatasetName());
        } 
        **/
        if(getPropValueAsBoolean("hasPageData") && !(myDataType.equals("Proteomics"))) {
            addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                            "GeneQuestions.GenesBy" + myDataType + "DirectWithConfidence" + getDatasetName());
        } else {

            addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                            "GeneQuestions.GenesBy" + myDataType + "Direct" + getDatasetName());
        }

        if(getPropValueAsBoolean("hasPercentileData")) {
	    if (myDataType.equals("Proteomics")) {
		addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
				"GeneQuestions.GenesBy" + myDataType + getDatasetName() + "Percentile");
	    } else {
		addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
				"GeneQuestions.GenesBy" + myDataType + "Direct" + getDatasetName() + "Percentile");

	    }
	}
    }



}
