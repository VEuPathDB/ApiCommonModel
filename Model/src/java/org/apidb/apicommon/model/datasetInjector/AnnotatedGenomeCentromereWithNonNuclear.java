package org.apidb.apicommon.model.datasetInjector;

public class AnnotatedGenomeCentromereWithNonNuclear extends AnnotatedGenomeWithNonNuclear {

  public void addModelReferences() {
      // add all references from AnnotatedGenome first
      super.addModelReferences();
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByCentromereProximity");
  }

}
