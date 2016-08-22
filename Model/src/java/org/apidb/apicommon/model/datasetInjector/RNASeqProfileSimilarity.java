package org.apidb.apicommon.model.datasetInjector;


public class RNASeqProfileSimilarity extends RNASeq {


    @Override
    public void injectTemplates() {
        super.injectTemplates();

        injectTemplate("rnaSeqProfileSimilarityQuestion");
        //        injectTemplate("rnaSeqProfileSimilarityCategories");
        setPropValue("searchCategory", "searchCategory-similarity");
        setPropValue("questionName", "GeneQuestions.GenesByRNASeq" + getDatasetName() + "ProfileSimilarity");
        injectTemplate("internalGeneSearchCategory");
    }


    @Override
    public void addModelReferences() {
	super.addModelReferences();

        addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
                        "GeneQuestions.GenesByRNASeq" + getDatasetName() + "ProfileSimilarity");

    }



    /**
    @Override
    public String[][] getPropertiesDeclaration() {
        String[][] parentDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {
                                   //                                   {"hasSimilarityData", ""},
        };

        return combinePropertiesDeclarations(parentDeclaration, declaration);
    }
    **/


}
