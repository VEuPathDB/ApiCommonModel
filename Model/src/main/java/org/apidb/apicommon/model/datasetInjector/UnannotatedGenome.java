package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

// Should really just be called Genome
public class UnannotatedGenome extends DatasetInjector {

  @Override
  public void injectTemplates() {
      //      injectTemplate("jbrowseNames");
  }

  @Override
  public void addModelReferences() {
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "attribute", "overview");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequenceBySourceId");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequencesByTaxon");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequencesBySimilarity");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "table", "Taxonomy");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "table", "SequencePieces");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "table", "Aliases");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "table", "Centromere");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "table", "SequenceComments");


    addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "attribute", "overview");
    addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "question", "SpanQuestions.DynSpansBySourceId");
    addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "question", "SpanQuestions.DynSpansByMotifSearch");


    addWdkReference("OrganismRecordClasses.OrganismRecordClass", "table", "SequenceCounts");
    addWdkReference("OrganismRecordClasses.OrganismRecordClass", "table", "GeneCounts");
    addWdkReference("OrganismRecordClasses.OrganismRecordClass", "table", "GenomeSequencingAndAnnotationAttribution");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
