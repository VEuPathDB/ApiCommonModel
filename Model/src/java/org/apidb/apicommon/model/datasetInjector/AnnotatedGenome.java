package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class AnnotatedGenome extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByLocation");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesBySimilarity");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GeneByLocusTag");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByTaxon");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByGeneType");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByExonCount");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesWithUserComments");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesWithSignalPeptide");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByTransmembraneDomains");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "overview");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "Notes");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "Alias");

    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "attribute", "overview");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequenceBySourceId");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequencesByTaxon");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequencesBySimilarity");

    addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolatesBySimilarity");

    addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "attribute", "overview");
    addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "question", "SpanQuestions.DynSpansBySourceId");
    addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "question", "SpanQuestions.DynSpansByMotifSearch");
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
