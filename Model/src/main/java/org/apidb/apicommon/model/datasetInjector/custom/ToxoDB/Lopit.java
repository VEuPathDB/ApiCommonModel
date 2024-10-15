package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class Lopit extends DatasetInjector {

  @Override
  public void injectTemplates() {

      
      setPropValue("presenterId", "DS_eda79f81b5");
      setPropValue("datasetClassCategoryIri", "http://edamontology.org/topic_0140");
      setPropValue("includeProjectsExcludeEuPathDB", "ToxoDB,UniDB");
      setPropValue("datasetDisplayName", "T. gondii ME49 Hyper LOPIT Global mapping of protein subcellular location");
      setShortAttribution();
      String organismAbbrevDisplay = ""; //getPropValue("organismAbbrevDisplay");
      setPropValue("organismAbbrevDisplay", organismAbbrevDisplay.replace(":", ""));

      injectTemplate("datasetCategory");
  }


  @Override
  public void addModelReferences() {
      // addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByLOPITtgonME49_lopit_LOPIT_RSRC"); 
     addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByLOPIT"); 
 

    addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "LOPITdescription");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "LOPITGraphSVG");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "LOPITMAP");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "LOPITMCMC");

  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
      String[][] propertiesDeclaration = {};
      return propertiesDeclaration;
  }



}
