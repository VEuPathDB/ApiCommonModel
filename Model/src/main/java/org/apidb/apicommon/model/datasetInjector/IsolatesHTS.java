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
 * into the conf, and nothing reads it - including addModelReferences(), which used to gate
 * the copy-number searches on it and now registers them unconditionally for the same
 * reason: the coverage data is there whatever the flag says.
 *
 * addModelReferences() registers the VARIANT record's searches and tables. It previously
 * registered SnpQuestions / SnpRecordClasses equivalents, which the Variant record
 * supersedes and whose XML is commented out of apiCommonModel.xml; that block was disabled
 * wholesale during dnaseq-merge-experiments and left the 195 dnaseq presenters registering
 * nothing at all. That is not cosmetic: GeneTables.MetaTable joins ApidbTuning.DatasetModelRef
 * to decide, per organism, which gene-record tables and attributes are in scope, so with no
 * rows the whole Genetic Variation section is out of scope for every dnaseq organism.
 *
 * SpanQuestions.VariantsBySpanLogic is deliberately absent - it is reached through the
 * span-logic machinery rather than from a dataset, so a dataset association would only add
 * a link nobody follows.
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

      // ---- Short Variant record ------------------------------------------------------
      // The five user-facing searches. VariantQuestions.VariantAlignmentForm is omitted:
      // its own description calls it internal - it exists to host the strain filter on the
      // record page, and is not something a dataset should advertise.
      addWdkReference("VariantRecordClasses.VariantRecordClass", "question", "VariantQuestions.VariantBySourceId");
      addWdkReference("VariantRecordClasses.VariantRecordClass", "question", "VariantQuestions.VariantsByIsolateGroup");
      addWdkReference("VariantRecordClasses.VariantRecordClass", "question", "VariantQuestions.VariantsByLocation");
      addWdkReference("VariantRecordClasses.VariantRecordClass", "question", "VariantQuestions.VariantsByGeneIds");
      addWdkReference("VariantRecordClasses.VariantRecordClass", "question", "VariantQuestions.VariantsByTwoIsolateGroups");

      addWdkReference("VariantRecordClasses.VariantRecordClass", "attribute", "record_overview");

      // The retired SNP record's Strains / HTSStrains / AlleleCount / CountrySummary /
      // StrainsSamples collapse into these four.
      addWdkReference("VariantRecordClasses.VariantRecordClass", "table", "TranscriptProducts");
      addWdkReference("VariantRecordClasses.VariantRecordClass", "table", "PredictedEffects");
      addWdkReference("VariantRecordClasses.VariantRecordClass", "table", "VariantStrains");
      addWdkReference("VariantRecordClasses.VariantRecordClass", "table", "VariantCountrySummary");

      // ---- Gene page: Genetic Variation section --------------------------------------
      // Exactly the columnAttributes of the GeneAttributes.VariationSummary block in
      // geneRecord.xml, in its order. These are what MetaTable scopes per organism, so an
      // attribute left out here is one the gene page will not show for any dnaseq organism.
      // The six hts_* attributes the old block named are gone with the SNP record.

      // basis - first, because nothing below is readable without it
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variation_strains_sampled");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variation_effective_ploidy");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variation_call_rate");

      // counts
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "total_variants");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_per_kb");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variant_snvs");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variant_indels");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variant_mixed");

      // predicted consequence
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_impact_high");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_impact_moderate");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_impact_low");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_impact_modifier");

      // effect classes
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_missense");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_synonymous");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_nonsense");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_frameshift");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_splice_disruptive");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_inframe_indel");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_utr");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_intron");

      // loss of function
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_lof");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_lof_common");

      // selection
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "pi_per_site");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "pi_n_pi_s");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "pi_syn_sites_used");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_common");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_missense_common");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "variants_singleton");

      // second caller, and continuity with the retired ratio attribute
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "pi_n_pi_s_product_call");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "nonsyn_syn_count_ratio");

      // Genome-browser link and the isolate alignment table both survive the SNP retirement
      // unchanged, so they keep their references.
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "SnpsGbrowseUrl");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "SNPsAlignment");

      // ---- Gene searches over variation ----------------------------------------------
      // Two, and they are not interchangeable: GenesByNgsSnps recomputes from the raw
      // alignments for a sample group the user picks, GenesByVariantCharacteristics reads
      // precomputed per-organism statistics. Each search's description points at the other,
      // which only works if a dataset offers both.
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByNgsSnps");
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByVariantCharacteristics");

      // ---- Copy number ---------------------------------------------------------------
      // Unconditional. These were gated on hasCNVData, which no longer describes the data:
      // the pipeline emits coverage for every dnaseq dataset regardless of what the
      // presenter declares, so the gate only hid working searches on the 77 that say false.
      addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequencesByPloidy");
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByCopyNumber");
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByCopyNumberComparison");

      // ---- Sample record -------------------------------------------------------------
      addWdkReference("SampleRecordClasses.SampleRecordClass", "table", "Datasets");
      addWdkReference("SampleRecordClasses.SampleRecordClass", "table", "Characteristics");
      addWdkReference("SampleRecordClasses.SampleRecordClass", "table", "ProcessedSample");
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
