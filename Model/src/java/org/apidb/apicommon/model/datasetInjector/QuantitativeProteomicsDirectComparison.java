package org.apidb.apicommon.model.datasetInjector;


public class QuantitativeProteomicsDirectComparison extends ExpressionTwoChannelDirectComparison {

    @Override
    protected void setProteinCodingProps() {
        setPropValue("defaultProteinCodingOnly", "no");
        setPropValue("proteinCodingParamVisible", "false");
        setPropValue("hasPercentileData", "false");
    }

    @Override
    protected String getSearchCategoryType() {
	return "proteomics";
    }



    @Override
    public void injectTemplates() {
        // hasPageData required by Expression class but not applicable to Proteomics;  Ensure it is always false
           setPropValue("hasPageData", "false");

      // TODO:  How else can we get this??
      setPropValue("datasetClassCategoryIri", "http://edamontology.org/topic_0108");


        super.injectTemplates();

        injectTemplate("proteomicsSimpleLogRatio");
    }

    @Override
    protected void setExprPlotPartModule() {
        setPropValue("exprPlotPartModule", "QuantMassSpec");
    }


    @Override
    protected void setExprGraphVisiblePart() {
        setPropValue("exprGraphVisiblePart", "exprn_val");
    }

    @Override
    protected void setGraphModule() {
        setPropValue("graphModule", "Proteomics::LogRatio");
    }


    @Override
    protected void setProfileSamplesHelp() {
        String profileSamplesHelp = "Protein Abundance Values for quantitative proteomics are log2 fold change (M = log2 (comparator/reference)).";

        setPropValue("profileSamplesHelp", profileSamplesHelp);
    }


    @Override
    protected void setGraphYAxisDescription() {
        String yAxisDescription = "Protein Abundance Values for quantitative proteomics are log2 fold change (M = log2 (comparator/reference)).  We also provide the fold difference in the right axis.  For any 2 points on the graph (M1, M2) the fold difference is calculated by:  power(2, M2)/power(2,M1).   or expression percentile value.";

        setPropValue("graphYAxisDescription", yAxisDescription);
    }

    @Override
    protected void setDataType() {
        setDataType("Proteomics");
    }

    @Override
    /**
     *  Override from superclass... do nothing because we get this from the prop Declaration
     */
    protected void setIsLogged() {}


  @Override
  public void addModelReferences() {
      super.addModelReferences();
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "ProteinExpressionGraphs");
  }


    @Override
    public String[][] getPropertiesDeclaration() {
        String[][] exprDeclaration = super.getPropertiesDeclaration();
        
        String [][] declaration = {{"isLogged", "Is the Data Logged or not"},
        };

        return combinePropertiesDeclarations(exprDeclaration, declaration);
    }

}
