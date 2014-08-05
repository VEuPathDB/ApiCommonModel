package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;
import java.util.List;

public class IsolatesHTS extends DatasetInjector {

  @Override
  public void injectTemplates() {
      String datasetName = getDatasetName();
      String[] datasetWords = datasetName.split("_");


      setOrganismAbbrevFromDatasetName();

      // trim off the prefix and suffix from the experiment name
      // new workflow uses different naming convention for HTS isolates, need to handle both.
      // pfal3D7_SNP_Conway_HTS_SNP_RSRC (build-18)
      // pfal3D7_HTS_SNP_Conway_HTS_SNP_RSRC (build-19)
      String experimentRsrc = datasetName.replaceFirst(datasetWords[0] + "_HTS_SNP_", "");
      experimentRsrc = experimentRsrc.replaceFirst(datasetWords[0] + "_SNP_", "");

      String experimentName = experimentRsrc.replaceFirst("_RSRC", "");
      setPropValue("experimentName", experimentName);

      // use getSampleList method, refer to - https://redmine.apidb.org/issues/16510
      //String projectName = getPropValue("projectName");
      String organismAbbrev = getPropValue("organismAbbrev");
      String sampleNamePrefix = ":" + organismAbbrev + "_" + experimentName + "_";
      String sampleNameSuffix = "_HTS_SNPSample_RSRC";
      List<String> sampleNames = getSampleList(sampleNamePrefix, sampleNameSuffix);

      String organismAbbrevDisplay = getPropValue("organismAbbrevDisplay");
      setPropValue("organismAbbrevDisplay", organismAbbrevDisplay.replace(":", ""));

      for (int i=0; i<sampleNames.size(); i++){
          setPropValue("sampleName", sampleNames.get(i));

          String gbrowseDBName = organismAbbrev + "_" + experimentName + "_" + sampleNames.get(i) + sampleNameSuffix;
          setPropValue("gbrowseDBName", gbrowseDBName);

          injectTemplate("htsSnpSampleDatabase");
          injectTemplate("htsSnpSampleCoverageXYTrack");
          injectTemplate("htsSnpSampleCoverageDensityTracks");
          injectTemplate("htsSnpSampleAlignmentTrack");
      }       

      /** commented out by Haiming Wang - use getSampleList method. refer to - https://redmine.apidb.org/issues/16510 
      String sampleList = getPropValue("sampleList");
      String[] samples = sampleList.split(" ");
      for(int i = 0; i < samples.length; i++) {
          setPropValue("sampleName", samples[i]);

          injectTemplate("htsSnpSampleDatabase");
          injectTemplate("htsSnpSampleCoverageXYTrack");
          injectTemplate("htsSnpSampleCoverageDensityTracks");
          injectTemplate("htsSnpSampleAlignmentTrack");
      }
      */

  }

  @Override
  public void addModelReferences() {
      // NGS SNPs
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.NgsSnpBySourceId");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.NgsSnpsByIsolateGroup");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.NgsSnpsByLocation");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.NgsSnpsByGeneIds");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.NgsSnpsByTwoIsolateGroups");

      /**
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.SnpBySourceId");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.SnpsByAlleleFrequency");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.SnpsByIsolatePattern");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.SnpsByIsolatesGroup");
      */ 

      addWdkReference("SnpRecordClasses.SnpRecordClass", "attribute", "snp_overview");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "attribute", "gene_context");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "table", "Strains");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "table", "Providers_other_SNPs");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "table", "HTSStrains");


      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "total_snps_all_strains");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByHtsSnps");
      //addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByTajimasDHtsSnps");

      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByIsolateId");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByTaxon");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByHost");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByIsolationSource");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByProduct");
      //addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByGenotypeNumber");
      //addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByRFLPGenotype");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByStudy");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByCountry");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByAuthor");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolatesByTextSearch");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolatesByClustering");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "table", "Reference");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "table", "HtsContacts");
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "attribute", "overview");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "SNPsAlignment");
  }



  // second column is for documentation
    @Override
  public String[][] getPropertiesDeclaration() {
      //String [][] declaration = {{"sampleList", "space del list of sample (sample name = directory name in webservices)"}
      //};
      String[][] declaration = {};

    return declaration;
  }


}
