package org.apidb.apicommon.model.datasetInjector;

public class AnnotatedGenomeCentromereTelomereWithNonNuclear extends AnnotatedGenomeWithNonNuclear {

  @Override
  public void addModelReferences() {
      // add all references from AnnotatedGenome first
      super.addModelReferences();
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByNonnuclearLocation");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByCentromereProximity");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByTelomereProximity");
  }

}
