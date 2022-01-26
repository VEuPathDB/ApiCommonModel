package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class PhenotypeScore extends DatasetInjector {

    protected String getInternalQuestionName() {
        return "GeneQuestions.GenesByPhenotype_" + getDatasetName();
    }

  @Override
  public void injectTemplates() {
      String projectName = getPropValue("projectName");
      setPropValue("includeProjects", projectName + ",UniDB");
      injectTemplate("phenotypeScoreQuestion");

      setPropValue("questionName", getInternalQuestionName());
      setPropValue("searchCategory", "searchCategory-phenotype-curated");
      injectTemplate("internalGeneSearchCategory");
  }

  @Override
  public void addModelReferences() {

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", getInternalQuestionName());
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "PhenotypeScore");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "PhenotypeScoreGraphs");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }

}
