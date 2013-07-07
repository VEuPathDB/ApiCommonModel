package org.apidb.apicommon.model.datasetInjector;

public class AnnotatedGenomeWithNonNuclear extends AnnotatedGenome {

  @Override
  public void addModelReferences() {
      // add all references from AnnotatedGenome first
      super.addModelReferences();
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByNonnuclearLocation");
  }

}
