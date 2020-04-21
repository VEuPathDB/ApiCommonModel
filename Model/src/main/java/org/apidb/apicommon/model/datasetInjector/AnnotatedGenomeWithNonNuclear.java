package org.apidb.apicommon.model.datasetInjector;

public class AnnotatedGenomeWithNonNuclear extends AnnotatedGenome {

  @Override
  public void addModelReferences() {
      // add all references from AnnotatedGenome first
      super.addModelReferences();
      if (!(getPropValue("projectName").equals("TriTrypDB"))){
        addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByNonnuclearLocation");
      }
  }

}
