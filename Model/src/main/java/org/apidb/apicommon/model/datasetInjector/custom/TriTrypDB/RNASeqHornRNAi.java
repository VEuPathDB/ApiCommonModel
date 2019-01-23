package org.apidb.apicommon.model.datasetInjector.custom.TriTrypDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class RNASeqHornRNAi extends DatasetInjector {

  @Override
  public void injectTemplates() {
      setPropValue("datasetClassCategoryIri", "http://edamontology.org/topic_3298");
      setPropValue("includeProjectsExcludeEuPathDB", "TriTrypDB,UniDB");
      setShortAttribution();
      String organismAbbrevDisplay = "T. brucei brucei TREU927"; //getPropValue("organismAbbrevDisplay");
      setPropValue("organismAbbrevDisplay", organismAbbrevDisplay.replace(":", ""));

      String xAxis = "No_Tet: uninduced control;<br> BFD3: bloodstream-form cells grown for 3 days;<br> BFD6: bloodstream-form cells grown for 6 days;<br> PF: insect/procyclic-form cells;<br> DIF: cells induced throughout growth as bloodstream forms, differentiation and growth as procyclic forms";
      setPropValue("graphXAxisSamplesDescription", xAxis.replace("'", ""));


      injectTemplate("datasetCategory");
      injectTemplate("profileSampleAttributesCategory");
      injectTemplate("profileAttributeQueries");
      injectTemplate("profileAttributeRef");
  }

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Horn::TbRNAiRNASeq"); 
        addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "PhenotypeGraphs");	
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByHighThroughputPhenotyping"); 
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
