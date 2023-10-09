package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;
import org.gusdb.wdk.model.WdkRuntimeException;

public class Coexpression extends  DatasetInjector {

  @Override
  public void injectTemplates() {
      setShortAttribution();

      String datasetName = getDatasetName();

      String dataSource  = getPropValue("dataSource");
      String exampleGeneIds  = getPropValue("exampleGeneIds");
      String spearmanCoefficient = getPropValue("spearmanCoefficient");
    }

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByCoexpression" + getDatasetName());

  }

  // declare properties required beyond those inherited from the datasetPresenter
  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String [][] propertiesDeclaration = { {"dataSource", "data source in the coexpression table"},
                                          {"exampleGeneIds", "Gene Ids provided as default on coexpression Q page"},
                                          {"defaultCoefficient", "Default value of Spearman Coefficient on Q page"},
    };

    return propertiesDeclaration;
  } 
}
