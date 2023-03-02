package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.model.datasetInjector.GeneList;

public class FunctionalGeneList extends  GeneList {

    public String searchCategory() {
        // Can add this back if we get more gene list searches
        return("searchCategory-functional-gene-list");
    }
    public String questionName() {
        return("GenesByFunctionalGeneList" + getDatasetName());

    }
    public String questionTemplateName() {
        return("geneListFunctional");
    }
}
