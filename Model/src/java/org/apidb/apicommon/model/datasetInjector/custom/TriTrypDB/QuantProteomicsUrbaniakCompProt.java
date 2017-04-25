package org.apidb.apicommon.model.datasetInjector.custom.TriTrypDB;

import org.apidb.apicommon.model.datasetInjector.ProteinExpressionMassSpec;

public class QuantProteomicsUrbaniakCompProt extends ProteinExpressionMassSpec  {

  @Override
  public void injectTemplates() {
      //inject all the templates in ProteinExpressionMassSpec first
      super.injectTemplates();
      
      //if a the graph has a different dataset name, use that name for the custom graph
      String graphDatasetName = getPropValue("graphDatasetName");
      if(!graphDatasetName.equals("")) {
          setPropValue("datasetName", graphDatasetName.replace("'", ""));
      }

      String description = getPropValue("datasetDescrip");
      setPropValue("datasetDescrip", description.replace("'", ""));

      
      String xAxis = getPropValue("graphXAxisSamplesDescription");
      setPropValue("graphXAxisSamplesDescription", xAxis.replace("'", ""));

      String yAxis = getPropValue("graphYAxisDescription");
      setPropValue("graphYAxisDescription", yAxis.replace("'", ""));


      setPropValue("isGraphCustom", "true");
      injectTemplate("genePageGraphDescriptions");
      injectTemplate("datasetExampleGraphDescriptions");
  }

  @Override
  public void addModelReferences() {
        //  add all references from ProteinExpressionMassSpec first
        super.addModelReferences();
        addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Urbaniak::CompProtQuantMS"); 
        addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByQuantProtDirecttbruTREU927_quantitativeMassSpec_Urbaniak_CompProt_RSRC");

  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {

      String[][] massSpecDeclaration = super.getPropertiesDeclaration();
      String[][] declaration = {    {"graphDatasetName", "This param allows for a different dataset name to be used for the graph"},
                                    {"graphModule", ""},
                                    {"graphXAxisSamplesDescription", ""},
                                    {"graphYAxisDescription", ""},
                                    {"graphVisibleParts", ""},
                                    {"graphPriorityOrderGrouping", ""},
      };
      return combinePropertiesDeclarations(massSpecDeclaration, declaration);
  }


}
