package org.apidb.apicommon.model.datasetInjector;


public class MicroarrayTwoChannelDirectComparison extends Microarray {

    @Override
    public void injectTemplates() {
        super.injectTemplates();

        setPropValue("decodeProfileSet", "");
        setPropValue("percentileProfileSetPattern", "%");

        injectTemplate("expressionProfileSetParamQuery");
        injectTemplate("expressionPctProfileSetParamQuery");

        String redPctSampleDecode = makeDecodeMappingStrings(getPropValue("redPctSampleMap"));
        String greenPctSampleDecode = makeDecodeMappingStrings(getPropValue("greenPctSampleMap"));

        setPropValue("redPctSampleDecode", redPctSampleDecode);
        setPropValue("greenPctSampleDecode", greenPctSampleDecode);

        injectTemplate("expressionSamplesParamQueryDirect");
        injectTemplate("expressionPctSamplesParamQueryDirect");

        if(getPropValueAsBoolean("hasPageData")) {
            injectTemplate("expressionFoldChangeWithConfidenceQuestionDirect");
            injectTemplate("microarrayFoldChangeWithConfidenceWSDirect");
        } else {
            injectTemplate("expressionFoldChangeQuestionDirect");
            injectTemplate("microarrayFoldChangeWSDirect");
        }


        if(getPropValueAsBoolean("hasPercentileData")) {
            injectTemplate("microarrayPercentileWSDirect");
            injectTemplate("expressionPercentileQuestionDirect");
        }

        injectTemplate("microarraySimpleTwoChannelGraph");
    }


    @Override
    protected void setExprPlotPartModule() {
        setPropValue("exprPlotPartModule", "LogRatio");
    }


    @Override
    protected void setExprGraphVisiblePart() {
        setPropValue("exprGraphVisiblePart", "exprn_val");
    }

    @Override
    protected void setGraphModule() {
        setPropValue("graphModule", "Microarray::TwoChannel");
    }

    @Override
    public void addModelReferences() {
	super.addModelReferences();

        if(getPropValueAsBoolean("hasPageData")) {
            addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                            "GeneQuestions.GenesByMicroarrayDirectWithConfidence" + getDatasetName());
        } else {
            addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                            "GeneQuestions.GenesByMicroarrayDirect" + getDatasetName());
        }

        if(getPropValueAsBoolean("hasPercentileData")) {
            addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
                            "GeneQuestions.GenesByMicroarrayDirect" + getDatasetName() + "Percentile");
        }
    }




    @Override
    public String[][] getPropertiesDeclaration() {
        String[][] microarrayDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {{"redPctSampleMap", "The ProfileElementName will be Like 'A vs B' ... Need to say whether A or B maps to this channel"},
                                   {"greenPctSampleMap", "The ProfileElementName will be Like 'A vs B' ... Need to say whether A or B maps to this channel"},
        };

        return combinePropertiesDeclarations(microarrayDeclaration, declaration);
    }

    @Override
    protected void setGraphYAxisDescription() {
        String yAxisDescription = "Expression Values for 2 channel microarray experiments are log ratios (M = log2 Cy5/Cy3).  We also provide the fold difference in the right axis.  For any 2 points on the graph (M1, M2) the  fold difference is calculated by:  power(2, (M2-M1)).   or expression percentile value.";

        setPropValue("graphYAxisDescription", yAxisDescription);
    }
}
