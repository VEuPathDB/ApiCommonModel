package org.apidb.apicommon.model.datasetInjector;

public class AnnotatedGenomeCentromereWithNonNuclear extends AnnotatedGenomeWithNonNuclear {

  @Override
  public void addModelReferences() {
      // add all references from AnnotatedGenome first
      super.addModelReferences();
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByCentromereProximity");
  }

}
