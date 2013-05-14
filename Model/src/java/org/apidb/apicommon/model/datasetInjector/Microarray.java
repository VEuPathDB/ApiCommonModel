package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public abstract class Microarray extends DatasetInjector {

    protected abstract void setExprGraphVisiblePart();
    protected abstract void setGraphModule();
    protected abstract void setExprPlotPartModule();

    protected abstract void setGraphYAxisDescription();

    protected void setProfileSetFilterPattern() {
        setPropValue("profileSetFilterPattern", "%");
    }

    /***
     *   list of key value pairs
     *      key1=value1;key2=value2
     *
     *    @rv String like 'key1', 'value1', 'key2', 'value2'
     */
    protected static String makeDecodeMappingStrings(String namesMap) {
        String decode = "";

        if(namesMap.equals("")) {
            return decode;
        }

        String[] pairs = namesMap.split(";");

        for(int i = 0; i < pairs.length; i++) {
            String[] profileMap = pairs[i].split("=");

            decode = decode + "'" + profileMap[0] + "', '" + profileMap[1] + "',\n";
        }

        return decode;
    }

  public void addModelReferences() {
      setGraphModule();
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", getPropValue("graphModule") + getDatasetName() ); 
  }

    public void injectTemplates() {

        // perl packages disallow some characters in the package name... use this to name the graphs
        setGraphDatasetName();

        String datasetName = getDatasetName();
        setPropValue("organismAbbrev", getOrganismAbbrevFromDatasetName());

        String projectName = getPropValue("projectName");

        if(getPropValueAsBoolean("isEuPathDBSite")) {
            setPropValue("includeProjects", projectName + ",EuPathDB");
            
        } else {
            setPropValue("includeProjects", projectName);
        }

        injectTemplate("microarrayAttributeCategory");

        setExprGraphVisiblePart();
        setGraphModule();
        setExprPlotPartModule();
        setGraphYAxisDescription();

        injectTemplate("microarrayGraphAttributesExpression");
        injectTemplate("microarrayGraphAttributesPercentile");

        String exprGraphVp = getPropValue("exprGraphVisiblePart");


        if(getPropValueAsBoolean("hasPercentileData")) {        
            setPropValue("graphVisibleParts", exprGraphVp + ",percentile");
        } else {
            setPropValue("graphVisibleParts", exprGraphVp);
        }

        // these are universal for injected microarray experiments
        setPropValue("graphGenePageSection", "expression");

        if(getPropValue("graphPriorityOrderGrouping").equals("")) {
            setPropValue("graphPriorityOrderGrouping", "1");
        }
        
        // need to make sure there are no single quotes in the descrip
        String datasetDescrip = getPropValue("datasetDescrip");
        setPropValue("datasetDescrip", datasetDescrip.replace("'", ""));

        setPropValue("isGraphCustom", "false");
        injectTemplate("genePageGraphDescriptions");

        String excludeProfileSets = getPropValue("excludedProfileSets");


        String excludedProfileSetsList = "'INTERNAL'";
        if(!excludeProfileSets.equals("")) {
            String[] excludedProfileSetsArr = excludeProfileSets.split(";");

            for(int i = 0; i < excludedProfileSetsArr.length; i++) {
                excludedProfileSetsList = excludedProfileSetsList + ", '" + excludedProfileSetsArr[i] + "'";
            }
        }

        setPropValue("excludedProfileSetsList", excludedProfileSetsList);
    }
    
    public String[][] getPropertiesDeclaration() {
        String [][] declaration = {
                                   {"hasPageData", ""},
                                   {"hasPercentileData", ""},
                                   {"isEuPathDBSite", ""},
                                   {"graphSampleLabels", "OPTIONAL Prop...provide if you want to override the sample names in the db"},
                                   {"graphColors", "semicolon sep list of colors"},
                                   {"excludedProfileSets", "OPTIONAL PROP... extra profile sets are loaded which we need to exclude from the graphs and questions"},
                                   {"graphBottomMargin", "Optionally override the default bottom margin size"},
                                   {"graphType", "one of bar or line"},
                                   {"graphForceXLabelsHorizontal", "true/false.  NOTE:  Only valid when graphType is bar"},
                                   {"optionalQuestionDescription", "This text will be appended to fold change and percentile questions"},
                                   {"graphXAxisSamplesDescription", "will show up on the gene record page next to the graph"},
                                   {"graphPriorityOrderGrouping", "numeric grouping / ordering of graphs on the gene record page"},
                                   {"linePlotXAxisLabel", "Sets the x-axis label for line graphs that don't override the xaxis tick mark labels."}
        };

        
        return declaration;
  }
}

