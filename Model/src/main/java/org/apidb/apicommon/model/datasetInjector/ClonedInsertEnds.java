package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class ClonedInsertEnds extends DatasetInjector {

  @Override
  public void injectTemplates() {
      injectTemplate("jbrowseClonedInsertEnds");
  }

  @Override
  public void addModelReferences() {
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
      String [][] declaration = {
          {"type", "cosmid,fosmid,bac,..."},
          {"sourceIdField", ""},
          {"sourceIdJoiningRegex", ""},
          {"spanLengthCutoff", ""},
          {"includeMultipleSpans", ""},
      };
    return declaration;
  }


}

