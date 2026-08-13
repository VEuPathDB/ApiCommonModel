package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;


public class Coexpression extends  DatasetInjector {

  @Override
  public void injectTemplates() {
      setShortAttribution();

      //String datasetName = getDatasetName();

      String projectName = getPropValue("projectName");
      //String dataSource  = getPropValue("dataSource");
      //String exampleGeneIds  = getPropValue("exampleGeneIds");
      //String defaultCoefficient = getPropValue("defaultCoefficient");

      if(getPropValueAsBoolean("isEuPathDBSite")) {
          setPropValue("includeProjects", projectName + ",EuPathDB,UniDB");
      } else {
          setPropValue("includeProjects", projectName + ",UniDB");
      }
      setPropValue("includeProjectsExcludeEuPathDB", projectName + ",UniDB");


      injectTemplate("datasetCategory");

      setPropValue("searchCategory", "searchCategory-coexpression");
      setPropValue("questionName", "GeneQuestions.GenesByCoexpression" + getDatasetName());
      injectTemplate("internalGeneSearchCategory");

      // apidb.genecoexpression rows are keyed by external_database_release_id, resolved
      // by joining sres.externaldatabaserelease/externaldatabase on name; the loading
      // workflow names that row by taking this dataset's own name, dropping "_array_",
      // and inserting "_geneCoexpression" before the trailing "_RSRC".
      setPropValue("dataSource", getDatasetName().replace("_array_", "_").replaceFirst("_RSRC$", "_geneCoexpression_RSRC"));

      injectTemplate("coexpressionQuestion");
      injectTemplate("coexpressionSourceQuery");
    }

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByCoexpression" + getDatasetName());

  }

  // declare properties required beyond those inherited from the datasetPresenter
  // second column is for documentation

  @Override
  public String[][] getPropertiesDeclaration() {
    String [][] propertiesDeclaration = { {"exampleGeneIds", "Gene Ids provided as default on coexpression Q page"},
                                          {"defaultCoefficient", "Default value of Spearman Coefficient on Q page"},
    };

    return propertiesDeclaration;
  } 
}
