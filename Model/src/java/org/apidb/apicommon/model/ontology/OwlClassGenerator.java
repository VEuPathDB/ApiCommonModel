package org.apidb.apicommon.model.ontology;

import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;

import org.kohsuke.args4j.CmdLineException;
import org.kohsuke.args4j.CmdLineParser;
import org.semanticweb.owlapi.apibinding.OWLManager;
import org.semanticweb.owlapi.model.AddAxiom;
import org.semanticweb.owlapi.model.IRI;
import org.semanticweb.owlapi.model.OWLAnnotation;
import org.semanticweb.owlapi.model.OWLAnnotationProperty;
import org.semanticweb.owlapi.model.OWLAxiom;
import org.semanticweb.owlapi.model.OWLClass;
import org.semanticweb.owlapi.model.OWLDataFactory;
import org.semanticweb.owlapi.model.OWLOntology;
import org.semanticweb.owlapi.model.OWLOntologyManager;
import org.semanticweb.owlapi.vocab.OWLRDFVocabulary;

/**
 * Read tab-delimited file and convert to ontology classes associated with some annotationProperties in OWL format
 *  	1st Row is header and need to skip
 *  	2nd Row specifies the AnnotationProperty ID in the ontology
 *  	By default, 1st Col is term label, 2nd Col is term parent IRI, and 4th Col and following are annotations of the term
 *
 *  We need to specify the starting ID need to assign to a new term, if the starting ID is -1, then the label of the term will be used as the ID
 *
 *  @author Jie Zheng
 */

public class OwlClassGenerator {
	public static void main(String[] args) {
		OwlClassGeneratorOptions bean = new OwlClassGeneratorOptions();
	    CmdLineParser parser = new CmdLineParser(bean);

	    try {
	        parser.parseArgument(args);
	    } catch( CmdLineException e ) {
	        System.err.println(e.getMessage());
	        parser.printUsage(System.err);
	        System.exit(1);
	    }

		String path = bean.getPath();
		String inputFilename = bean.getInputFilename();
		String idBase = bean.getIdBase();
		String domainName = bean.getDomainName();
		String outputFilename = bean.getOutputFilename();
		String ontoIRIstr = bean.getOntoIRIstr();
		int labelPos = bean.getLabelPos();
		int parentPos = bean.getParentPos();
		int annotPos = bean.getAnnotPos();
		int startId = bean.getStartId();

		// load tab-delimited file
		BufferedReader br = null;
		ArrayList <String[]> matrix = new ArrayList <String[]> ();

		try {
			br = new BufferedReader(new FileReader(path + inputFilename));

			String line = br.readLine();

			while( (line = br.readLine()) != null)
			{
				String[] items = line.split("\t");
				matrix.add(items);
			}
			System.out.println("Successfully read text file: " + inputFilename);
		} catch (FileNotFoundException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		} finally {
			try {
				if ( br != null ) br.close();
			}
			catch (IOException ex) {
				ex.printStackTrace();
			}
		}

    	// create an OWL file
        OWLOntologyManager manager = OWLManager.createOWLOntologyManager();
		OWLOntology outOWL = OntologyManipulator.create(manager, ontoIRIstr);

        // Create factory to obtain a reference to a class
        OWLDataFactory df = manager.getOWLDataFactory();

        // Create annotation properties based on the IDs provided in the tab-delimited file on the 2nd row
        ArrayList<OWLAnnotationProperty> annotProps = new ArrayList<OWLAnnotationProperty>();
        String[] items = matrix.get(0);
        for (int k = annotPos; k< items.length; k++) {
        	if (items[k].trim().length() > 0) {
        		OWLAnnotationProperty annotProp = df.getOWLAnnotationProperty(IRI.create(idBase +items[k].trim()));
        		annotProps.add(annotProp);
        	}
        }

        // create classes
	   	for (int i = 1; i < matrix.size(); i++) {
	   		items = matrix.get(i);

	   		// generate class IRI
	   		String termIRIstr;

	   		if (startId == -1) {
	   			termIRIstr = ontoIRIstr + "#" +  items[labelPos].trim();
	   		} else {
	   			termIRIstr = idBase + getOntologyTermID(domainName,startId);
	   			startId ++;
	   		}

	   		OWLClass cls = df.getOWLClass(IRI.create(termIRIstr));

	   		// add class parent
	   		OWLClass parent = null;
	   		String parentStr = items[parentPos].trim();
	   		if (parentStr.startsWith("http")) {
	   			parent = df.getOWLClass(IRI.create(parentStr));
	   		} else if (parentStr.length() > 0){
	   			parent = df.getOWLClass(IRI.create(ontoIRIstr + "#" + parentStr));
	   		} else {
	   			parent = df.getOWLClass(IRI.create("http://www.w3.org/2002/07/owl#Thing"));
	   		}
	   		
	   		OWLAxiom axiom = df.getOWLSubClassOfAxiom(cls, parent);
	   		manager.applyChange(new AddAxiom(outOWL, axiom));

	        // add term label
	        OWLAnnotationProperty labelProp = df.getOWLAnnotationProperty(OWLRDFVocabulary.RDFS_LABEL.getIRI());
	        OWLAnnotation label = df.getOWLAnnotation(labelProp, df.getOWLLiteral(items[labelPos].trim()));
	        axiom = df.getOWLAnnotationAssertionAxiom(cls.getIRI(), label);
        	manager.applyChange(new AddAxiom(outOWL, axiom));
        	//System.out.println(termIRIstr + "\t" + items[labelPos].trim());

	        // add other annotation properties
	        for (int j = annotPos; j < items.length; j ++) {
	        	if (items[j].trim().length()>0 && annotProps.size() > j-annotPos) {
	        		OWLAnnotation annot = df.getOWLAnnotation(annotProps.get(j-annotPos), df.getOWLLiteral(items[j].trim()));
	        		axiom = df.getOWLAnnotationAssertionAxiom(cls.getIRI(), annot);
	        		manager.applyChange(new AddAxiom(outOWL, axiom));
	        	}
	        }
	   	}

	   	OntologyManipulator.saveToFile(manager, outOWL, path + outputFilename);
	}

	public static String getOntologyTermID (String domainName, int startID) {
		String s = "0000000" + startID;
		String id = domainName.toUpperCase() + "_" + s.substring(s.length()-7);

		return id;
	}
}
