package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.AnnotatedGenomeCentromereWithNonNuclear;


public class AnnotatedGenomeME49 extends AnnotatedGenomeCentromereWithNonNuclear {

  @Override
  public void addModelReferences() {
      // add all references from AnnotatedGenome first
      super.addModelReferences();
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "CrisprPhenotypeGraphs");
  }

}
