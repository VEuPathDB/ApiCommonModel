package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class MicroarrayTwoChannelDirectComparison extends Microarray {
  
    /***
     *   list of key value pairs
     *      key1=value1;key2=value2
     *
     *    @rv String like 'key1', 'value1', 'key2', 'value2'
     */
    public String makeDecodeStmtFromSampleMap(String sampleMap) {
        String[] pairs = sampleMap.split(";");

        String decode = "";

        for(int i = 0; i < pairs.length; i++) {
            String[] profileMap = pairs[i].split("=");
            decode = decode + "'" + profileMap[0] + "', '" + profileMap[1] + "',\n";
        }

        return decode;
    }



    public void injectTemplates() {
        super.injectTemplates();

        injectTemplate("microarrayProfileSetParamQueryDirect");
        injectTemplate("microarrayPctProfileSetParamQueryDirect");

        if(getPropValueAsBoolean("hasPageData")) {
            injectTemplate("microarrayFoldChangeWithConfidenceQuestionDirect");
            injectTemplate("microarrayFoldChangeWithConfidenceWSDirect");
        } else {
            injectTemplate("microarrayFoldChangeQuestionDirect");
            injectTemplate("microarrayFoldChangeWSDirect");
        }

        String redPctSampleDecode = makeDecodeStmtFromSampleMap(getPropValue("redPctSampleMap"));
        String greenPctSampleDecode = makeDecodeStmtFromSampleMap(getPropValue("greenPctSampleMap"));

        setPropValue("redPctSampleDecode", redPctSampleDecode);
        setPropValue("greenPctSampleDecode", greenPctSampleDecode);

        injectTemplate("microarrayPercentileWSDirect");
        injectTemplate("microarrayPercentileQuestionDirect");

        injectTemplate("microarraySimpleTwoChannelGraph");
    }


    protected void setExprPlotPartModule() {
        setPropValue("exprPlotPartModule", "LogRatio");
    }


    protected void setExprGraphVisiblePart() {
        setPropValue("exprGraphVisiblePart", "expr_val");
    }

    protected void setGraphModule() {
        setPropValue("graphModule", "Microarray::TwoChannel");
    }

    public void addModelReferences() {

        if(getPropValueAsBoolean("hasPageData")) {
            //            addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
            //                            "GenesByMicroarray" + getDatasetName() + "Confidence");
        } else {
            //            addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
            //                            "GenesByMicroarray" + getDatasetName());
        }

            //        addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
            //                        "GenesByMicroarray" + getDatasetName() + "Percentile");
    }




    public String[][] getPropertiesDeclaration() {
        String[][] microarrayDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {{"redPctSampleMap", "The ProfileElementName will be Like 'A vs B' ... Need to say whether A or B maps to this channel"},
                                   {"greenPctSampleMap", "The ProfileElementName will be Like 'A vs B' ... Need to say whether A or B maps to this channel"},
        };

        return combinePropertiesDeclarations(microarrayDeclaration, declaration);
    }


}
