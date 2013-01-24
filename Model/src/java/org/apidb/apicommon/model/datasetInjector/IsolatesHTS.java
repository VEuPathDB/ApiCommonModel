package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class IsolatesHTS extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.SnpBySourceId");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.HtsSnpsByGeneId");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.HtsSnpsByLocation");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.HtsSnpsByStrain");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.SnpsByAlleleFrequency");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.SnpsByIsolatePattern");

      addWdkReference("SnpRecordClasses.SnpRecordClass", "attribute", "snp_overview");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "attribute", "gene_context");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "table", "Strains");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "table", "Providers_other_SNPs");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "table", "HTSStrains");


      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "total_snps_all_strains");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByHtsSnps");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByTajimasDHtsSnps");

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
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "table", "Reference");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "table", "HtsContacts");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "attribute", "overview");
  }


  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
