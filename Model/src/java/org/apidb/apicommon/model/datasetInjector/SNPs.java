package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class SNPs extends DatasetInjector {

  @Override
  public void injectTemplates() {
  }

  @Override
  public void addModelReferences() {
    addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.SnpBySourceId");
    addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.SnpsByGeneId");
    addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.SnpsByLocation");
    addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.SnpsByAlleleFrequency");
    addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.SnpsByIsolatePattern");
    addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.SnpsByIsolateType");
    addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.SnpsByStrain");
    addWdkReference("SnpRecordClasses.SnpRecordClass", "attribute", "snp_overview");
    addWdkReference("SnpRecordClasses.SnpRecordClass", "attribute", "gene_context");
    addWdkReference("SnpRecordClasses.SnpRecordClass", "table", "Strains");
    addWdkReference("SnpRecordClasses.SnpRecordClass", "table", "Providers_other_SNPs");

    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByNgsSnps");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "SNPs");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "total_hts_snps");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
