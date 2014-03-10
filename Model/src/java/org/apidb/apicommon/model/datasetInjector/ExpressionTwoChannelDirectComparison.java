package org.apidb.apicommon.model.datasetInjector;


public abstract class ExpressionTwoChannelDirectComparison extends Expression {

    @Override
    public void injectTemplates() {
        super.injectTemplates();

        setPropValue("decodeProfileSet", "");
        setPropValue("percentileProfileSetPattern", "%");

        injectTemplate("expressionProfileSetParamQuery");

        String lcDataType = getPropValue("dataType").toLowerCase();

        String redPctSampleDecode = makeDecodeMappingStrings(getPropValue("redPctSampleMap"));
        String greenPctSampleDecode = makeDecodeMappingStrings(getPropValue("greenPctSampleMap"));

        setPropValue("redPctSampleDecode", redPctSampleDecode);
        setPropValue("greenPctSampleDecode", greenPctSampleDecode);
        if(getPropValueAsBoolean("hasPageData") && lcDataType.equals("proteomics")) {
            injectTemplate("expressionSamplesParamQueryDirectFDR");
        } else {
            injectTemplate("expressionSamplesParamQueryDirect");
        }
        injectTemplate("expressionPctSamplesParamQueryDirect");

        if(getPropValueAsBoolean("hasPageData") && lcDataType.equals("proteomics")) {
            injectTemplate("expressionFoldChangeWithFDRQuestionDirect");
            injectTemplate(lcDataType + "FoldChangeWithFDRCategoriesDirect");
        } else if (getPropValueAsBoolean("hasPageData") && !(lcDataType.equals("proteomics"))) {
            injectTemplate("expressionFoldChangeWithConfidenceQuestionDirect");
            injectTemplate(lcDataType + "FoldChangeWithConfidenceCategoriesDirect");
        } else {
            injectTemplate("expressionFoldChangeQuestionDirect");
            injectTemplate(lcDataType + "FoldChangeCategoriesDirect");
        }

        if(getPropValueAsBoolean("hasPercentileData")) {
            injectTemplate("expressionPctProfileSetParamQuery");
            injectTemplate(lcDataType + "PercentileCategoriesDirect");
            injectTemplate("expressionPercentileQuestionDirect");
        }


    }



    @Override
    public void addModelReferences() {
	super.addModelReferences();

        setDataType();

        String dataType = getDataType();


        if(getPropValueAsBoolean("hasPageData") && dataType.equals("Proteomics")) {
            addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                            "GeneQuestions.GenesBy" + dataType + "DirectWithFDR" + getDatasetName());
        } else if(getPropValueAsBoolean("hasPageData") && !(dataType.equals("Proteomics"))) {
            addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                            "GeneQuestions.GenesBy" + dataType + "DirectWithConfidence" + getDatasetName());
        } else {
            addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                            "GeneQuestions.GenesBy" + dataType + "Direct" + getDatasetName());
        }

        if(getPropValueAsBoolean("hasPercentileData")) {
            addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                            "GeneQuestions.GenesBy" + dataType + "Direct" + getDatasetName() + "Percentile");
        }
    }




    @Override
    public String[][] getPropertiesDeclaration() {
        String[][] exprDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {{"redPctSampleMap", "The ProfileElementName will be Like 'A vs B' ... Need to say whether A or B maps to this channel"},
                                   {"greenPctSampleMap", "The ProfileElementName will be Like 'A vs B' ... Need to say whether A or B maps to this channel"},
        };

        return combinePropertiesDeclarations(exprDeclaration, declaration);
    }

}
