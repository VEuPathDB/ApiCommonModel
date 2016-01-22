
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
        if(!lcDataType.equals("proteomics")) { 
                String channelOnePctSampleDecode = makeDecodeMappingStrings(getPropValue("channelOnePctSampleMap"));
                String channelTwoPctSampleDecode = makeDecodeMappingStrings(getPropValue("channelTwoPctSampleMap"));
                
                setPropValue("channelOnePctSampleDecode", channelOnePctSampleDecode);
                setPropValue("channelTwoPctSampleDecode", channelTwoPctSampleDecode);
        } else {
            setPropValue("defaultFoldDifference","1.5");
                
        }
        if(getPropValueAsBoolean("hasPageData") && lcDataType.equals("proteomics")) {
            injectTemplate("expressionSamplesParamQueryDirectFDR");
        } else {
            injectTemplate("expressionSamplesParamQueryDirect");
        }

        if(getPropValueAsBoolean("hasPageData") && lcDataType.equals("proteomics")) {
            injectTemplate("expressionFoldChangeWithFDRQuestionDirect");
            //            injectTemplate(lcDataType + "FoldChangeWithFDRCategoriesDirect");
            setPropValue("searchCategory", "searchCategory-fold-change-with-fdr");
            setPropValue("questionName", "GeneQuestions.GenesBy" + getDataType() + "DirectWithFDR" + getDatasetName());
            injectTemplate("internalGeneSearchCategory");




        } else if (getPropValueAsBoolean("hasPageData") && !(lcDataType.equals("proteomics"))) {
            injectTemplate("expressionFoldChangeWithConfidenceQuestionDirect");
            //            injectTemplate(lcDataType + "FoldChangeWithConfidenceCategoriesDirect");
            setPropValue("searchCategory", "searchCategory-fold-change-with-confidence");
            setPropValue("questionName", "GeneQuestions.GenesBy" + getDataType() + "DirectWithConfidence" + getDatasetName());
            injectTemplate("internalGeneSearchCategory");

        } else {
            injectTemplate("expressionFoldChangeQuestionDirect");

            //injectTemplate(lcDataType + "FoldChangeCategoriesDirect");
            setPropValue("searchCategory", "searchCategory-direct-comparison");
            setPropValue("questionName", "GeneQuestions.GenesBy" + getDataType() + "Direct" + getDatasetName());
            injectTemplate("internalGeneSearchCategory");
        }

        if(getPropValueAsBoolean("hasPercentileData")) {
            injectTemplate("expressionPctSamplesParamQueryDirect");
            injectTemplate("expressionPctProfileSetParamQuery");

            //            injectTemplate(lcDataType + "PercentileCategoriesDirect");
            setPropValue("searchCategory", "searchCategory-percentile");
            setPropValue("questionName", "GeneQuestions.GenesBy" + getDataType() + "Direct" + getDatasetName() + "Percentile");
            injectTemplate("internalGeneSearchCategory");


            injectTemplate("expressionPercentileQuestionDirect");
        }


    }



    @Override
    public void addModelReferences() {
	super.addModelReferences();

        setDataType();

        String myDataType = getDataType();


        if(getPropValueAsBoolean("hasPageData") && myDataType.equals("Proteomics")) {
            addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                            "GeneQuestions.GenesBy" + myDataType + "DirectWithFDR" + getDatasetName());
        } else if(getPropValueAsBoolean("hasPageData") && !(myDataType.equals("Proteomics"))) {
            addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                            "GeneQuestions.GenesBy" + myDataType + "DirectWithConfidence" + getDatasetName());
        } else {
            addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                            "GeneQuestions.GenesBy" + myDataType + "Direct" + getDatasetName());
        }

        if(getPropValueAsBoolean("hasPercentileData")) {
            addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                            "GeneQuestions.GenesBy" + myDataType + "Direct" + getDatasetName() + "Percentile");
        }
    }




}
