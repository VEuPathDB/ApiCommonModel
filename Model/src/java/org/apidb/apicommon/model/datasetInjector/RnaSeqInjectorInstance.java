package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetInjector.DatasetInjectorInstance;
import java.util.Map;

public class RnaSeqInjectorInstance extends  DatasetInjectorInstance {
  
  /*
   * getPropValues() gets the property values provided by the datasetPresenter
   * xml file. they are validated against the names provided in
   * getPropertyNames(). in the code below, the whole bundle is passed to each
   * of the templates even though a given template might not need all of them.
   * this is just convenience, rather than tailoring the list per template, it
   * is safe to pass all in, because unneeded ones will be ignored.
   */

  public void injectTemplates() {

    Map<String, String> propValues = di.getPropValues();

    di.injectTemplate("rnaSeqFoldChangePvalueQuestion", propValues);

    di.injectTemplate("rnaSeqFoldChangeQuestion", propValues);

    di.injectTemplate("rnaSeqPercentileQuestion", propValues);

    di.injectTemplate("expressionGraphAttribute", propValues);

    propValues.put("profileType", "foldChange");
    di.injectTemplate("expressionParamQuery", propValues);

    propValues.put("profileType", "percentile");
    di.injectTemplate("expressionParamQuery", propValues);

    di.injectTemplate("rnaSeqCoverageTrack", propValues);

  }

  public void insertReferences() {
    di.makeWdkReference("GeneRecordClasses.GeneRecordClass", "question",
        "GeneQuestions.GenesByRNASeq_" + di.getDatasetName() + "_FoldChangePValue");
  }
  
  // declare properties required beyond those inherited from the datasetPresenter
  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String [][] declaration = {};
    return declaration;
  }
}
