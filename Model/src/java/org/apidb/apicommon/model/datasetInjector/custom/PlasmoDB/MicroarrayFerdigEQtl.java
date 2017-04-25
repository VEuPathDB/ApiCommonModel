package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.MicroarrayTwoChannelReferenceDesign;

public class MicroarrayFerdigEQtl extends MicroarrayTwoChannelReferenceDesign {



    @Override
    public void injectTemplates() {
        
      // TODO:  How else can we get this??
      setPropValue("datasetClassCategoryIri", "http://edamontology.org/topic_3298");
      super.injectTemplates();
    }

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Ferdig::Dd2Hb3Similarity"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Ferdig::DD2_X_HB3"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByEqtlProfileSimilarity"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByEQTL_HaploGrpSimilarity"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByEQTL_Segments"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "Plasmo_eQTL_Table"); 
      addWdkReference("SpanRecordClasses.SpanRecordClass", "question", "SpanQuestions.DynSpansByEQTLtoGenes"); 
  }

    @Override
    protected void setDataType() {
        setDataType("Phenotype");
    }

}

