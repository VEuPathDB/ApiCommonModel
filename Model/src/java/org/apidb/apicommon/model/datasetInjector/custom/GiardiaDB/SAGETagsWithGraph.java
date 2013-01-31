package org.apidb.apicommon.model.datasetInjector.custom.GiardiaDB;

import org.apidb.apicommon.model.datasetInjector.SAGETags;

public class SAGETagsWithGraph extends SAGETags {

  public void addModelReferences() {
      // add all references from SAGETags first
      super.addModelReferences();
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Sage::McArthur");
  }

}
