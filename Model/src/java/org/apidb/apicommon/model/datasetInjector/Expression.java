package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public abstract class Expression extends DatasetInjector {

    protected String dataType;

    protected void setDataType(String dataType) {
        this.dataType = dataType;
        setPropValue("dataType", dataType);
    }

    protected String getDataType() {
        return this.dataType;
    }

    protected abstract void setDataType();
    protected abstract void setExprGraphVisiblePart();
    protected abstract void setGraphModule();
    protected abstract void setExprPlotPartModule();

    protected abstract void setGraphYAxisDescription();

    protected void setProfileSetFilterPattern() {
        setPropValue("profileSetFilterPattern", "%");
    }


    /***
     *
     *  used by the model (0=false, 1=true)
     *
     */
    protected void setIsLogged() {
        setPropValue("isLogged", "1"); 
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

    @Override
    public void addModelReferences() {
      setGraphModule();
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", getPropValue("graphModule") + getDatasetName() ); 
    }

    @Override
    public void injectTemplates() {

        // perl packages disallow some characters in the package name... use this to name the graphs
        setGraphDatasetName();


        setPropValue("organismAbbrev", getOrganismAbbrevFromDatasetName());

        String projectName = getPropValue("projectName");

        if(getPropValueAsBoolean("isEuPathDBSite")) {
            setPropValue("includeProjects", projectName + ",EuPathDB");
            
        } else {
            setPropValue("includeProjects", projectName);
        }

        setIsLogged();
        setDataType();
        setExprGraphVisiblePart();
        setGraphModule();
        setExprPlotPartModule();
        setGraphYAxisDescription();

        String lcDataType = getPropValue("dataType").toLowerCase();

        injectTemplate(lcDataType + "AttributeCategory");

        injectTemplate("expressionGraphAttributesExpression");

        if(getPropValueAsBoolean("hasPercentileData")) {
            injectTemplate("expressionGraphAttributesPercentile");
        }

        String exprGraphVp = getPropValue("exprGraphVisiblePart");


        if(getPropValueAsBoolean("hasPercentileData")) {        
            setPropValue("graphVisibleParts", exprGraphVp + ",percentile");
        } else {
            setPropValue("graphVisibleParts", exprGraphVp);
        }

        // these are universal for injected expression experiments
        setPropValue("graphGenePageSection", "expression");

        if(getPropValue("graphPriorityOrderGrouping").equals("")) {
            setPropValue("graphPriorityOrderGrouping", "1");
        }
        
        // need to make sure there are no single quotes in the descrip
        String datasetDescrip = getPropValue("datasetDescrip");
        setPropValue("datasetDescrip", datasetDescrip.replace("'", ""));

        setPropValue("isGraphCustom", "false");

        injectTemplate(lcDataType + "GraphDescriptions");

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

    @Override
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

