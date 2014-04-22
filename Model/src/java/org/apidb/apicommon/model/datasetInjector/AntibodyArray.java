package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class AntibodyArray extends DatasetInjector {

    protected void setGraphYAxisDescription() {
        String yAxisDescription = "Arcsinh(1+50x) transform of signal intensity";

        setPropValue("graphYAxisDescription", yAxisDescription);
    }

    protected void setProfileSetFilterPattern() {
        setPropValue("profileSetFilterPattern", "%");
    }



    @Override
    public void addModelReferences() {
        //  setGraphModule();
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", getPropValue("graphModule") + getDatasetName() ); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByAntibodyArray"  + getDatasetName() );
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



        String excludeProfileSets = getPropValue("excludedProfileSets");

        String excludedProfileSetsList = "'INTERNAL'";
        if(!excludeProfileSets.equals("")) {
            String[] excludedProfileSetsArr = excludeProfileSets.split(";");

            for(int i = 0; i < excludedProfileSetsArr.length; i++) {
                excludedProfileSetsList = excludedProfileSetsList + ", '" + excludedProfileSetsArr[i] + "'";
            }
        }

        setPropValue("excludedProfileSetsList", excludedProfileSetsList);
        injectTemplate("antibodyArrayProfileSetParamQuery");

        injectTemplate("antibodyArrayQuestion");

        //   injectTemplate("antibodyArrayCategories");

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
        };

        
        return declaration;
  }
}

