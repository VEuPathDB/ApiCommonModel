package org.apidb.apicommon.model.datasetInjector;

public class AnnotatedGenomeTelomere extends AnnotatedGenome {

  @Override
  public void addModelReferences() {
      // add all references from AnnotatedGenome first
      super.addModelReferences();
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByTelomereProximity");
  }

}
