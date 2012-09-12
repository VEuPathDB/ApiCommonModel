package org.apidb.apicommon.model.templateInjector;

import org.apidb.apicommon.templateInjector.TemplateInjector;

import java.util.Properties;

public class RnaSeqInjector extends TemplateInjector {

    /* 
	getPropValues() gets the property values provided by the datasetPresenter xml file.  they are validated
	against the names provided in getPropertyNames().  in the code below, the whole bundle is passed to each
	of the templates even though a given template might not need all of them.   this is just convenience, rather
	than tailoring the list per template, it is safe to pass all in, because unneeded ones will be ignored.

     */

    public void run() {

	Properties propValues = getPropValues();

	injectWdkTemplate("rnaSeqFoldChangePvalueQuestion", propValues);
	injectWdkTemplate("rnaSeqFoldChangeQuestion", propValues);
	injectWdkTemplate("rnaSeqPercentileQuestion", propValues);
	injectWdkTemplate("expressionGraphAttribute", propValues);

	propValues.setProperty("profileType", "foldChange");
	injectWdkTemplate("expressionParamQuery", propValues);

	propValues.setProperty("profileType", "percentile");
	injectWdkTemplate("expressionParamQuery", propValues);

	injectGbrowseTemplate("rnaSeqCoverageTrack", propValues);
	
    }

    // second column is for documentation
    public String[][] getPropertyNames() {
	String[][] s = { 
	    {"datasetName", "Internal name for dataset"},
	    {"datasetDisplayName", "Used in display name for questions"},
	    {"datasetShortDisplayName", "Used in shortDisplayName for questions and in gbrowse track category"},
	    {"datasetDescrip", "Used in question"},
	    {"projectName", ""},
	    {"buildNumberIntroduced", "The first build in which this dataset was introduced"},
	    {"organismShortName", "Used in gbrowse track category.  Alternatively, could be gotten from join to ApiDB.Organism"},
		};
	return s;
    }
}
