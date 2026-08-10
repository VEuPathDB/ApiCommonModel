package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

/**
 * DNASeq dataset injector.
 *
 * Injects the per-DATASET jbrowse properties only. The per-SAMPLE properties this used to
 * inject are gone on purpose: which samples an experiment has, and which measures each of
 * those samples has, are now read from the webservices tree at request time by
 * ApiCommonModel::Model::JbrowseDnaSeqTracks. So this class supplies what only a presenter
 * can know (display name, summary, attribution, category) and the filesystem supplies what
 * only the pipeline can know (samples and their files). One fact, one owner.
 *
 * That split is also what fixes the breakage it replaced. The old per-sample loop called
 * getSampleList(), which keys samples on organismAbbrev + datasetClassCategory +
 * experimentName by scanning sibling dataset props. The merged dnaseqExperiment class
 * carries an empty category while its samples span two ("Genetic variation" for SNPs,
 * "Structural variation" for CNVs), so that key cannot match and getSampleList() throws.
 * Removing the per-sample path removes the only caller.
 *
 * hasCNVData deliberately survives as declared-but-unused. Presenters still supply it (118
 * say true, 77 say false) but the pipeline now emits _normalisedCoverage.bw regardless, so
 * the flag no longer describes the data. It stays declared here because presenters pass it
 * and getPropertiesDeclaration is what validates presenter props; it is no longer emitted
 * into the conf, and nothing reads it.
 *
 * addModelReferences() stays commented out: it registered SnpQuestions / SnpRecordClasses
 * references, XML which is not in the compiled model and which the Variant record
 * supersedes.
 */
public class IsolatesHTS extends DatasetInjector {

  @Override
  public void injectTemplates() {
      setOrganismAbbrevFromDatasetName();

      // collapse the presenter's wrapped CDATA summary onto one line; it becomes a
      // single key=value line in datasetAndPresenterProps.conf, which is parsed linewise
      setPropValue("summary", getPropValue("summary").replaceAll("\n", " "));
      setPropValue("summary", getPropValue("summary").replaceAll(" +", " "));

      injectTemplate("jbrowseDnaSeqBuildProps");
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
