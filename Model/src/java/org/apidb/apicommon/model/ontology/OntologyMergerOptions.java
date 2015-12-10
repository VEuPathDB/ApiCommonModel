package org.apidb.apicommon.model.ontology;

import org.kohsuke.args4j.Option;

/**
 *  Process arguments passed from command line for OntologyMerger.java
 *
 *  @author Jie Zheng
 */
public class OntologyMergerOptions {
    @Option(name="-path", usage ="the directory contains input file and also for saved output file", required = false)
    private String path = "C:/Users/jiezheng/Documents/EuPathDB/ontology/";

    @Option(name="-inputFilename", usage="OWL file which contains owl import statements", required = false)
    private String inputFilename = "eupath.owl";

    @Option(name="-outputFilename", usage="The filename of output OWL file", required = false)
    private String outputFilename = "eupath_merged.owl";

    @Option(name="-ontoIRIstr", usage="IRI of ontology contains term display labels in OWL format", required = false)
    private String ontoIRIstr = "http://purl.obolibrary.org/obo/eupath/eupath_merged.owl";

    public String getPath () {
    	return this.path;
    }

    public String getInputFilename () {
    	return this.inputFilename;
    }

    public String getOutputFilename () {
    	return this.outputFilename;
    }

    public String getOntoIRIstr () {
    	return this.ontoIRIstr;
    }
}
