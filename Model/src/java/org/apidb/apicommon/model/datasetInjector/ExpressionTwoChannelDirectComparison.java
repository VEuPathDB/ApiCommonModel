package org.apidb.apicommon.model.datasetInjector;


public abstract class ExpressionTwoChannelDirectComparison extends Expression {

    @Override
    public void injectTemplates() {
        super.injectTemplates();

        setPropValue("decodeProfileSet", "");
        setPropValue("percentileProfileSetPattern", "%");

        injectTemplate("expressionProfileSetParamQuery");
        injectTemplate("expressionPctProfileSetParamQuery");

        String lcDataType = getPropValue("dataType").toLowerCase();

        String redPctSampleDecode = makeDecodeMappingStrings(getPropValue("redPctSampleMap"));
        String greenPctSampleDecode = makeDecodeMappingStrings(getPropValue("greenPctSampleMap"));

        setPropValue("redPctSampleDecode", redPctSampleDecode);
        setPropValue("greenPctSampleDecode", greenPctSampleDecode);

        injectTemplate("expressionSamplesParamQueryDirect");
        injectTemplate("expressionPctSamplesParamQueryDirect");

        if(getPropValueAsBoolean("hasPageData")) {
            injectTemplate("expressionFoldChangeWithConfidenceQuestionDirect");
            injectTemplate(lcDataType + "FoldChangeWithConfidenceWSDirect");
        } else {
            injectTemplate("expressionFoldChangeQuestionDirect");
            injectTemplate(lcDataType + "FoldChangeWSDirect");
        }


        if(getPropValueAsBoolean("hasPercentileData")) {
            injectTemplate(lcDataType + "PercentileWSDirect");
            injectTemplate("expressionPercentileQuestionDirect");
        }


    }



    @Override
    public void addModelReferences() {
	super.addModelReferences();

        setDataType();

        String dataType = getDataType();

        if(getPropValueAsBoolean("hasPageData")) {
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
