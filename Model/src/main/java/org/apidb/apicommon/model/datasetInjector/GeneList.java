package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class GeneList extends  DatasetInjector {

  @Override
    public void injectTemplates() {
      setShortAttribution();


      String projectName = getPropValue("projectName");
      //String presenterId = getPropValue("presenterId");
      //String datasetName = getDatasetName();

      setOrganismAbbrevFromDatasetName();

     if(getPropValueAsBoolean("isEuPathDBSite")) {
          setPropValue("includeProjects", projectName + ",EuPathDB,UniDB");
      } else {
          setPropValue("includeProjects", projectName + ",UniDB");
      }

     String searchCategory = "searchCategory-functional-gene-list";
     String questionName = "GeneQuestions.GenesByFunctionalGeneList" + getDatasetName();

     setPropValue("searchCategory", searchCategory);
     setPropValue("questionName", questionName);

     injectTemplate("geneListFunctional");
     injectTemplate("internalGeneSearchCategory");
    }


  @Override
    public void addModelReferences() {
                addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                                "GeneQuestions.GenesByFunctionalGeneList" + getDatasetName());
  }


  @Override
  public String[][] getPropertiesDeclaration() {
      String [][] declaration = {
                                 {"isEuPathDBSite", ""}
                                 };
      return declaration;
          }

  
}
