package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class Pathways extends DatasetInjector {

  @Override
  public void injectTemplates() {
  }

  @Override
  public void addModelReferences() {
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "CompoundsMetabolicPathways");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "MetabolicPathways");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByMetabolicPathways");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByMetabolicPathway");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByPathwaysTransform");
    addWdkReference("PathwayRecordClasses.PathwayRecordClass", "table", "CompoundsMetabolicPathways");
    addWdkReference("PathwayRecordClasses.PathwayRecordClass", "table", "PathwayReactionsXrefs");
    addWdkReference("PathwayRecordClasses.PathwayRecordClass", "question", "PathwayQuestions.PathwaysByPathwayID");
    addWdkReference("PathwayRecordClasses.PathwayRecordClass", "question", "PathwayQuestions.PathwaysByGeneList");
    addWdkReference("PathwayRecordClasses.PathwayRecordClass", "question", "PathwayQuestions.PathwaysByCompounds");
    addWdkReference("CompoundRecordClasses.CompoundRecordClass", "table", "CompoundsMetabolicPathways");
    addWdkReference("CompoundRecordClasses.CompoundRecordClass", "question", "CompoundQuestions.CompoundsByPathway");
    addWdkReference("CompoundRecordClasses.CompoundRecordClass", "question", "CompoundQuestions.CompoundsByPathwayID");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}

