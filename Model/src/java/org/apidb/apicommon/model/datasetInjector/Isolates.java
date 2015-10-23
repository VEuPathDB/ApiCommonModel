package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class Isolates extends DatasetInjector {

  @Override
  public void injectTemplates() {
  }

  @Override
  public void addModelReferences() {

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesBySnps");

      addWdkReference("SnpChipRecordClasses.SnpChipRecordClass", "question", "SnpChipQuestions.SnpBySourceId");
      addWdkReference("SnpChipRecordClasses.SnpChipRecordClass", "question", "SnpChipQuestions.SnpsByGeneId");
      addWdkReference("SnpChipRecordClasses.SnpChipRecordClass", "question", "SnpChipQuestions.SnpsByLocation");
      addWdkReference("SnpChipRecordClasses.SnpChipRecordClass", "question", "SnpChipQuestions.SnpsByStrain");
      addWdkReference("SnpChipRecordClasses.SnpChipRecordClass", "question", "SnpChipQuestions.SnpsByIsolatePattern");

      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByIsolateId");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByTaxon");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByHost");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByIsolationSource");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByProduct");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByGenotypeNumber");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByRFLPGenotype");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByStudy");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByCountry");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByAuthor");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolatesByTextSearch");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolatesByClustering");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolatesBySimilarity");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "table", "Reference");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "attribute", "overview");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
