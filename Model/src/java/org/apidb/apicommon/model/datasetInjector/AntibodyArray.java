package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class AntibodyArray extends DatasetInjector {

    protected void setGraphYAxisDescription() {
        String yAxisDescription = "Log2 transform of signal intensity";
        if(getPropValue("function").equals("arcsinh")) {
            yAxisDescription = "Arcsinh(1+50x) transform of signal intensity";
        }
        setPropValue("graphYAxisDescription", yAxisDescription);
    }

    protected void setProfileSetFilterPattern() {
        setPropValue("profileSetFilterPattern", "%");
    }

    protected void setFunctionProperties() {
        if(getPropValue("function").equals("")) {
            setPropValue("function", "log2");
        } else if(getPropValue("function").equals("arcsinh")) {
            setPropValue("function_display", "(arcsinh(1+50x))");
            setPropValue("function_help","The arcsinh(1+50x) transform of the average intensity values for the");
        } else {
            setPropValue("function_display", "(log2)");
            setPropValue("function_help","The log base 2 transform of the average intensity values for the");
        }
    }
    @Override
    public void addModelReferences() {
        //  setGraphModule();
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", getPropValue("graphModule") + getDatasetName() ); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByAntibodyArray"  + getDatasetName() );
    }

    @Override
    public void injectTemplates() {

        // perl packages disallow some characters in the package name... use this to name the graphs
        setGraphDatasetName();

        setOrganismAbbrevFromDatasetName();

        String projectName = getPropValue("projectName");

        if(getPropValueAsBoolean("isEuPathDBSite")) {
            setPropValue("includeProjects", projectName + ",EuPathDB");
            
        } else {
            setPropValue("includeProjects", projectName);
        }


        //        setGraphModule();
        setGraphYAxisDescription();


        injectTemplate("antibodyArrayGraphAttributesExpression");



        injectTemplate("pathwayGraphs");

            setPropValue("graphVisibleParts", "xy_scatter");
    

        // these are universal for injected expression experiments
        setPropValue("graphGenePageSection", "host response");

        if(getPropValue("graphPriorityOrderGrouping").equals("")) {
            setPropValue("graphPriorityOrderGrouping", "1");
        }
        
        // need to make sure there are no single quotes in the descrip
        String datasetDescrip = getPropValue("datasetDescrip");
        setPropValue("datasetDescrip", datasetDescrip.replace("'", ""));

        setPropValue("isGraphCustom", "true");
 
        if(getPropValue("defaultGraphCategory").equals("")) {
                setPropValue("defaultGraphCategory","age");
            }

        String excludeProfileSets = getPropValue("excludedProfileSets");

        String excludedProfileSetsList = "'INTERNAL'";
        if(!excludeProfileSets.equals("")) {
            String[] excludedProfileSetsArr = excludeProfileSets.split(";");

            for(int i = 0; i < excludedProfileSetsArr.length; i++) {
                excludedProfileSetsList = excludedProfileSetsList + ", '" + excludedProfileSetsArr[i] + "'";
            }
        }

        setPropValue("excludedProfileSetsList", excludedProfileSetsList);
        setFunctionProperties() ;

        String help = getPropValue("function_help");
        System.out.println(help);

        String fn_display = getPropValue("function_display");
        System.out.println(fn_display);

        injectTemplate("antibodyArrayProfileSetParamQuery");

        injectTemplate("antibodyArrayQuestion");

        injectTemplate("antibodyArrayCategories");

        injectTemplate("antibodyArrayAttributeCategory");
        injectTemplate("antibodyArrayGraphDescriptions");

        injectTemplate("datasetExampleGraphDescriptions");
		}

    @Override
    public String[][] getPropertiesDeclaration() {
        String [][] declaration = {
                                   {"isEuPathDBSite", ""},
                                   {"excludedProfileSets", "OPTIONAL PROP... extra profile sets are loaded which we need to exclude from the graphs and questions"},
                                   {"optionalQuestionDescription", "This text will be appended to fold change and percentile questions"},
                                   {"graphXAxisSamplesDescription", "will show up on the gene record page next to the graph"},
                                   {"graphPriorityOrderGrouping", "numeric grouping / ordering of graphs on the gene record page"},
                                   {"graphModule", ""},
                                   {"defaultGraphCategory"},
                                   {"function", ""},
        };

        
        return declaration;
  }
}

