package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;
import java.util.List;

/**
 * DNASeq dataset injector.
 *
 * Both method bodies are commented out for the dnaseq-merge-experiments work: DNASeq
 * datasets are processed differently now, so neither what this injected nor what it
 * referenced describes them any more. Concretely:
 *
 *   - injectTemplates() derived per-sample gbrowse/jbrowse databases from getSampleList(),
 *     which keys samples on organismAbbrev + datasetClassCategory + experimentName. The new
 *     dnaseqExperiment class carries an empty category while its samples span two
 *     ("Genetic variation" for SNPs, "Structural variation" for CNVs), so that key cannot
 *     match and getSampleList() throws.
 *   - addModelReferences() registered SnpQuestions / SnpRecordClasses references. That XML
 *     is not in the compiled model and is to be superseded by the variation record.
 *
 * The class stays in place as a no-op so presenters may keep naming it while the new
 * processing lands; getPropertiesDeclaration() is left alone so the hasCNVData prop that
 * presenters still supply remains declared.
 */
public class IsolatesHTS extends DatasetInjector {

  @Override
  public void injectTemplates() {
      /* commented out for dnaseq-merge-experiments; see the class comment above
      String datasetName = getDatasetName();
      setOrganismAbbrevFromDatasetName();

      String experimentName = getPropValue("name");
      setPropValue("experimentName", experimentName);

      //      injectTemplate("jbrowseDNASeq");

      // : is a reserved character in gbrowse 
      String datasetDisplayName = getPropValue("datasetDisplayName");
      setPropValue("datasetDisplayName", datasetDisplayName.replace("-", ""));

      // use getSampleList method, refer to - https://redmine.apidb.org/issues/16510
      String organismAbbrev = getPropValue("organismAbbrev");
      String sampleNameSuffix = "_HTS_SNPSample_RSRC";
      List<String> sampleNames = getSampleList();

      String organismAbbrevDisplay = getPropValue("organismAbbrevDisplay");
      setPropValue("organismAbbrevDisplay", organismAbbrevDisplay.replace(":", ""));

      for (int i=0; i<sampleNames.size(); i++){
          setPropValue("sampleName", sampleNames.get(i));

          String gbrowseDBName = organismAbbrev + "_" + experimentName + "_" + sampleNames.get(i) + sampleNameSuffix;
          setPropValue("gbrowseDBName", gbrowseDBName);

          injectTemplate("htsSnpSampleDatabase");
          injectTemplate("htsSnpSampleCoverageXYTrack");

          //          setPropValue("gbrowseTrackName", gbrowseDBName);
          //          injectTemplate("gbrowseTrackCategory");

          injectTemplate("htsSnpSampleCoverageDensityTracks");
          injectTemplate("htsSnpSampleAlignmentTrack");
	  
          injectTemplate("jbrowseDnaSeqSampleBuildProps");

      }
      setPropValue("summary", getPropValue("summary").replaceAll("\n", " "));
      setPropValue("summary", getPropValue("summary").replaceAll(" +", " "));
      //String shortAttribution = getPropValue("shortAttribution");
      injectTemplate("jbrowseDnaSeqBuildProps");

      if(getPropValueAsBoolean("hasCNVData")) {

          setPropValue("datasetName", datasetName.replaceFirst("_HTS_SNP_", "_copyNumberVariations_"));
          
          for (int i=0; i<sampleNames.size(); i++) {
              setPropValue("sampleName", sampleNames.get(i));
              injectTemplate("copyNumberVariationsDatabase");
              injectTemplate("copyNumberVariationsTrack");

              //              setPropValue("gbrowseTrackName", getPropValue("datasetName") + getPropValue("sampleName"));
              //              injectTemplate("gbrowseTrackCategory");
          }       
      }

	//System.err.println("short attribution" + getPropValue("shortAttribution"));
      */
  }

  @Override
  public void addModelReferences() {
      /* commented out for dnaseq-merge-experiments; see the class comment above
      // NGS SNPs
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.NgsSnpBySourceId");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.NgsSnpsByIsolateGroup");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.NgsSnpsByLocation");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.NgsSnpsByGeneIds");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "question", "SnpQuestions.NgsSnpsByTwoIsolateGroups");


      addWdkReference("SnpRecordClasses.SnpRecordClass", "attribute", "snp_overview");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "attribute", "gene_context");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "table", "Strains");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "table", "Providers_other_SNPs");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "table", "HTSStrains");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "table", "AlleleCount");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "table", "CountrySummary");
      addWdkReference("SnpRecordClasses.SnpRecordClass", "table", "StrainsSamples");

      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "SnpsGbrowseUrl");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "total_hts_snps");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "hts_nonsynonymous_snps");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "hts_synonymous_snps");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "hts_noncoding_snps");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "hts_stop_codon_snps");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "hts_nonsyn_syn_ratio");

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByNgsSnps");
      //addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByTajimasDHtsSnps");

      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "SNPsAlignment");

      if(getPropValueAsBoolean("hasCNVData")) {
      addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequencesByPloidy");
	  addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByCopyNumber");
	  addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByCopyNumberComparison");
      }
      addWdkReference("SampleRecordClasses.SampleRecordClass", "table", "Datasets");
      addWdkReference("SampleRecordClasses.SampleRecordClass", "table", "Characteristics");
      addWdkReference("SampleRecordClasses.SampleRecordClass", "table", "ProcessedSample");
      */

 }



  // second column is for documentation
    @Override
  public String[][] getPropertiesDeclaration() {
      //String [][] declaration = {{"sampleList", "space del list of sample (sample name = directory name in webservices)"}
      //};
      String[][] declaration = {
         {"hasCNVData", ""},
      };


    return declaration;
  }


}
