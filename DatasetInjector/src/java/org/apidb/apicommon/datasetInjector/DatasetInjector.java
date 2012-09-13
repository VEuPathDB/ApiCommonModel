package org.apidb.apicommon.datasetInjector;

import java.util.Properties;

public class DatasetInjector {
    protected String datasetName;

    protected Properties getPropValues() { return null; }

    protected void injectWdkTemplate(String templateName, Properties propValues) {}

    protected void injectGbrowseTemplate(String templateName, Properties propValues) {}

    // discovers datasetName from propValues
    protected void makeWdkReference(String recordClass, String type, String name) {}

}
 
