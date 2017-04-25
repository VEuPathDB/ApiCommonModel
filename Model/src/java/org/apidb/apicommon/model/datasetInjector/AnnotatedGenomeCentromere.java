package org.apidb.apicommon.model.datasetInjector;

public class AnnotatedGenomeCentromere extends AnnotatedGenome {

  @Override
  public void addModelReferences() {
      // add all references from AnnotatedGenome first
      super.addModelReferences();
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByCentromereProximity");
  }

}
