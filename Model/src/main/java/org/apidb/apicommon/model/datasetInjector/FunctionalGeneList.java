package org.apidb.apicommon.model.datasetInjector;

public class FunctionalGeneList extends  GeneList {

    @Override
    public String searchCategory() {
        // Can add this back if we get more gene list searches
        return("searchCategory-functional-gene-list");
    }
    @Override
    public String questionName() {
        return("GenesByFunctionalGeneList" + getDatasetName());

    }
    @Override
    public String questionTemplateName() {
        return("geneListFunctional");
    }
}
