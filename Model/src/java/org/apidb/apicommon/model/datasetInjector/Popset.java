package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class Popset extends DatasetInjector {

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

      addWdkReference("PopsetRecordClasses.PopsetRecordClass", "question", "PopsetQuestions.PopsetByPopsetId");
      addWdkReference("PopsetRecordClasses.PopsetRecordClass", "question", "PopsetQuestions.PopsetByTaxon");
      addWdkReference("PopsetRecordClasses.PopsetRecordClass", "question", "PopsetQuestions.PopsetByHost");
      addWdkReference("PopsetRecordClasses.PopsetRecordClass", "question", "PopsetQuestions.PopsetByIsolationSource");
      addWdkReference("PopsetRecordClasses.PopsetRecordClass", "question", "PopsetQuestions.PopsetByProduct");
      addWdkReference("PopsetRecordClasses.PopsetRecordClass", "question", "PopsetQuestions.PopsetByGenotypeNumber");
      addWdkReference("PopsetRecordClasses.PopsetRecordClass", "question", "PopsetQuestions.PopsetByRFLPGenotype");
      addWdkReference("PopsetRecordClasses.PopsetRecordClass", "question", "PopsetQuestions.PopsetByStudy");
      addWdkReference("PopsetRecordClasses.PopsetRecordClass", "question", "PopsetQuestions.PopsetByCountry");
      addWdkReference("PopsetRecordClasses.PopsetRecordClass", "question", "PopsetQuestions.PopsetByAuthor");
      addWdkReference("PopsetRecordClasses.PopsetRecordClass", "question", "PopsetQuestions.PopsetsByTextSearch");
      addWdkReference("PopsetRecordClasses.PopsetRecordClass", "question", "PopsetQuestions.PopsetsByClustering");
      addWdkReference("PopsetRecordClasses.PopsetRecordClass", "question", "PopsetQuestions.PopsetsBySimilarity");
      addWdkReference("PopsetRecordClasses.PopsetRecordClass", "table", "Reference");
      addWdkReference("PopsetRecordClasses.PopsetRecordClass", "attribute", "overview");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
