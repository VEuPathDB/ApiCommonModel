package org.apidb.apicommon.model.datasetInjector;

public class MicroarrayTwoChannel extends  Microarray {

    /***
     *   list of key value pairs
     *      key1=value1;key2=value2
     *    @rv String like 'key1', 'value1', 'key2', 'value2'
     */
    protected void setDecodePercentileProp() {
        String datasetName = getDatasetName();
        String projectName = getPropValue("percentileProfileSetMap");
        String[] pairs = datasetName.split(";");

        String decode = "";

        //        for(int i = 0; i < pairs.length; i++) {
        //  String[] profileMap = pairs[i].split("=");
            //                decode = decode + "'" + profileMap[0] + "', '" + profileMap[1] + "',\n";
        //        }

        setPropValue("decode", decode);
    }


    protected boolean isDirectComparison() {
        return getPropValueAsBoolean("isDirectComparison");
    }


    public void injectTemplates() {
        super.injectTemplates();


        System.out.println("injecting specific templates");

        injectTemplate("twoChannelMicroarrayExpressionGraphAttributes");

        injectTemplate("microarraySimpleTwoChannel");

    }



    public String[][] getPropertiesDeclaration() {
        String[][] microarrayDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {{"percentileProfileSetMap", "map green and red channels to samples or conditions"},
                                   {"excludedGraphProfileSets", "sometimes... extra profile sets are loaded which we need to exclude from the graphs"},
                                   {"graphType", "one of bar or line"},
                                   {"isDirectComparison", "true/false"},
        };

        return combinePropertiesDeclarations(microarrayDeclaration, declaration);
    }

}
