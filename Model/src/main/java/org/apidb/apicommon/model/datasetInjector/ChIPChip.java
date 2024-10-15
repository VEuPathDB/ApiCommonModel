package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class ChIPChip extends DatasetInjector {

  @Override
  public void injectTemplates() {
    setPropValue ("organismAbbrevDisplay", getOrganismAbbrevDisplayFromDatasetName());
    String featureName = getPropValue("datasetDisplayName").replace(' ', '_');
    setPropValue ("featureName", featureName);

    String projectName = getPropValue("projectName");
    setPropValue("includeProjects", projectName + ",UniDB");

    setPropValue("includeProjectsExcludeEuPathDB", projectName + ",UniDB");

    setPropValue("searchCategory", "Epigenomics");

    String cleanDatasetName = getDatasetName().replace('.', '_');
    setPropValue ("cleanDatasetName", cleanDatasetName);

    setPropValue("questionName", "GeneQuestions.GenesByChIPchip"+ cleanDatasetName);
    injectTemplate("chipchipCategories");

    injectTemplate("internalGeneSearchCategory");

    String key = getPropValue("key");
    if (key.length() != 0) {
        setPropValue ("key", " - " + key);
    }

    injectTemplate("chipChipSmoothed");

    if (getPropValueAsBoolean("hasCalledPeaks")) {
        injectTemplate("chipchipQuestion");
    }

  }

  @Override
  public void addModelReferences() {

      String cleanDatasetName = getDatasetName().replace('.', '_');
      setPropValue ("cleanDatasetName", cleanDatasetName);

      if (getPropValueAsBoolean("hasCalledPeaks")) {
	  addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByChIPchip"+ cleanDatasetName);
      }
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
