package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.model.datasetInjector.RNASeq;

public class RNASeqProfileSimilarity extends RNASeq {


    @Override
    public void injectTemplates() {
        super.injectTemplates();

        injectTemplate("rnaSeqProfileSimilarityQuestion");
        injectTemplate("rnaSeqProfileSimilarityCategories");
    }


    @Override
    public void addModelReferences() {
	super.addModelReferences();

        addWdkReference("GeneRecordClasses.GeneRecordClass", "question",
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
