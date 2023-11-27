package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public abstract class GeneList extends  DatasetInjector {

    public abstract String searchCategory();
    public abstract String questionName();
    public abstract String questionTemplateName();

    @Override
    public void injectTemplates() {
      setShortAttribution();

      String projectName = getPropValue("projectName");

      setOrganismAbbrevFromDatasetName();

     if(getPropValueAsBoolean("isEuPathDBSite")) {
          setPropValue("includeProjects", projectName + ",EuPathDB,UniDB");
      } else {
          setPropValue("includeProjects", projectName + ",UniDB");
      }


     String searchCategory = searchCategory();
     String questionName = questionName();
     String questionTemplateName = questionTemplateName();

     setPropValue("searchCategory", searchCategory);
     setPropValue("questionName", questionName);

     injectTemplate(questionTemplateName);


     setPropValue("questionName", "GeneQuestions." + questionName);
     injectTemplate("internalGeneSearchCategory");
    }


  @Override
    public void addModelReferences() {
     String questionName = questionName();

     addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                     "GeneQuestions." + questionName);
  }


  @Override
  public String[][] getPropertiesDeclaration() {
      String [][] declaration = {
                                 {"isEuPathDBSite", ""}
                                 };
      return declaration;
          }

  
}
