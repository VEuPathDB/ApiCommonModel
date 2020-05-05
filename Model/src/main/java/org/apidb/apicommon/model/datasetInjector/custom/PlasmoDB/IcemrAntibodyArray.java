package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.AntibodyArray;

public class IcemrAntibodyArray extends AntibodyArray {

  @Override
  public void addModelReferences() {
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByICEMRHostResponse");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "ICEMR::AbMicroarray");

    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "HostResponseGraphs");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] exprDeclaration = super.getPropertiesDeclaration();
    String[][] propertiesDeclaration = {};
    return combinePropertiesDeclarations(exprDeclaration, propertiesDeclaration);
  }

    @Override
    public void injectTemplates() {
        setGraphDatasetName();
        setOrganismAbbrevFromDatasetName();

        String projectName = getPropValue("projectName");

        if(getPropValueAsBoolean("isEuPathDBSite")) {
            setPropValue("includeProjects", projectName + ",EuPathDB,UniDB");
        } else {
            setPropValue("includeProjects", projectName + ",UniDB");
        }
        setPropValue("includeProjectsExcludeEuPathDB", projectName + ",UniDB");

        setGraphYAxisDescription();

        injectTemplate("antibodyArrayGraphAttributesExpression");

        if(getPropValue("isGraphCustom").equals("true")) {
            setPropValue("isGraphCustom", "true");
        }

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

	// NOT inject question in the model or ontology

        injectTemplate("antibodyArrayGraphDescriptions");
        injectTemplate("datasetExampleGraphDescriptions");
		}

}
