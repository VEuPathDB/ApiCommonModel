package org.apidb.apicommon.model.ontology;

import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;

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
 * 	Read tab-delimited file and convert to ontology classes associated with some annotationProperties in OWL format
 *  	1st Row is header and need to skip
 *  	2nd Row specifies the AnnotationProperty ID in the ontology
 *  	1st Col is term label
 *  	3rd Col is term parent IRI
 *  	4th Col and following are annotations of the term
 *  
 *  Generate ICEMR india variables as classes
 *  
 *  @author Jie Zheng
 */

public class OwlClassGenerator {
	public static void main(String[] args) {
		// path that contains ICEMR terminology related documents
		String path = "/home/jbrestel/data/edam/";
		
		// Ontology term URI base
		String idBase = "http://purl.obolibrary.org/eupath/";

		// input tab-delimited file
		String inFilename = "individuals.txt";	
		int labelPos = 0;
		int parentPos = 1;
		int annotPos = 3;
		
		// unique ID assigned to the newly added terms
		int startID = 1;
		
		// output owl file for variables
		//String ontIRIstr = "http://purl.obolibrary.org/obo/eupath/indiaStudyType.owl";
		//String outFilename = "indiaStudyType.owl";
		String ontIRIstr = "http://purl.obolibrary.org/obo/eupath/categories.owl";
		String outFilename = "categories.owl";
		
		// load tab-delimited file 
		BufferedReader br = null;
		ArrayList <String[]> matrix = new ArrayList <String[]> ();
		
		try {
			br = new BufferedReader(new FileReader(path + inFilename));
			
			String line = br.readLine(); 
			String[] colNames = line.split("\t");
			
			while( (line = br.readLine()) != null)
			{
				String[] items = line.split("\t"); 				
				matrix.add(items);
			}
			System.out.println("Successfully read text file: " + inFilename);
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
		OWLOntology outOWL = OntologyManipulator.create(manager, ontIRIstr);

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
	   		String termIRIstr = idBase + getEupathID(startID);
	   		startID ++;  
	   			
	   		OWLClass cls = df.getOWLClass(IRI.create(termIRIstr));

	   		// add class parent
	   		OWLClass parent = df.getOWLClass(IRI.create(items[parentPos].trim()));
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
	        	if (items[j].trim().length()>0) {
	        		OWLAnnotation annot = df.getOWLAnnotation(annotProps.get(j-annotPos), df.getOWLLiteral(items[j].trim()));        	
	        		axiom = df.getOWLAnnotationAssertionAxiom(cls.getIRI(), annot);
	        		manager.applyChange(new AddAxiom(outOWL, axiom));
	        	}
	        }
	   	}

	   	OntologyManipulator.saveToFile(manager, outOWL, path + outFilename);  	
	}

	public static String getEupathID (int startID) {
		String s = "0000000" + startID; 
		String id = "CATEGORIES_" + s.substring(s.length()-7);
		
		return id;
	}
}
