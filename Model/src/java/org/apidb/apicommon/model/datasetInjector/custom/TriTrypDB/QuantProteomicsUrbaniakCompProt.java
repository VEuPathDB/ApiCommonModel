package org.apidb.apicommon.model.datasetInjector.custom.TriTrypDB;

import org.apidb.apicommon.model.datasetInjector.ProteinExpressionMassSpec;

public class QuantProteomicsUrbaniakCompProt extends ProteinExpressionMassSpec  {

  public void injectTemplates() {

      String description = getPropValue("datasetDescrip");
      setPropValue("datasetDescrip", description.replace("'", ""));

      
      String xAxis = getPropValue("graphXAxisSamplesDescription");
      setPropValue("graphXAxisSamplesDescription", xAxis.replace("'", ""));

      String yAxis = getPropValue("graphYAxisDescription");
      setPropValue("graphYAxisDescription", yAxis.replace("'", ""));


      setPropValue("isGraphCustom", "true");
      injectTemplate("genePageGraphDescriptions");
  }

  public void addModelReferences() {
        //  add all references from ProteinExpressionMassSpec first
        super.addModelReferences();
        addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Urbaniak::CompProtQuantMS"); 


  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {

      String[][] massSpecDeclaration = super.getPropertiesDeclaration();
      String[][] declaration = {    {"graphModule", ""},
                                    {"graphXAxisSamplesDescription", ""},
                                    {"graphYAxisDescription", ""},
                                    {"graphVisibleParts", ""},
                                    {"graphPriorityOrderGrouping", ""},
      };
      return combinePropertiesDeclarations(massSpecDeclaration, declaration);
  }


}
