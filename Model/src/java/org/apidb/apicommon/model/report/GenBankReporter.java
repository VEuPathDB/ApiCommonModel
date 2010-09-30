package org.apidb.apicommon.model.report;

import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.security.NoSuchAlgorithmException;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.Map;

import org.gusdb.wdk.model.AnswerValue;
import org.gusdb.wdk.model.Question;
import org.gusdb.wdk.model.RecordInstance;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.WdkUserException;
import org.gusdb.wdk.model.report.Reporter;
import org.json.JSONException;

public class GenBankReporter extends Reporter {

    private static final String PROPERTY_GENE_QUESTION = "gene_question";
    private static final String PROPERTY_SEQUENCE_ID_PARAM = "sequence_param";
    private static final String PROPERTY_PAGE_SIZE = "page_size";
    private static final String PROPERTY_SEQUENCE_ID_COLUMN = "sequence_id";
    private static final String CONFIG_SELECTED_COLUMNS = "selectedFields";

    public GenBankReporter(AnswerValue answerValue, int startIndex,
			   int endIndex) {
	super(answerValue, startIndex, endIndex);
    }

    // Take a sequence question, collect the sequence ids
    // For each page of sequence ids, pass the list of
    // ids to some other question
    // Go through the pages of gene records, writing as
    // genbank table format

    public void configure(Map<String, String> config) {
	super.configure(config);

	// list of columns to dump for genes (why?)
    }

    public String getConfigInfo() {
	return "This reporter does not have config info yet.";
    }

    public void write(OutputStream out) throws WdkModelException,
            NoSuchAlgorithmException, SQLException, JSONException,
            WdkUserException {
	PrintWriter writer = new PrintWriter(new OutputStreamWriter(out));

	String rcName = getQuestion().getRecordClass().getFullName();
	if (!rcName.equals("SequenceRecordClasses.SequenceRecordClass"))
            throw new WdkModelException("Unsupported record type: " + rcName);

	pageSequences(writer);
    }

    private void pageSequences(PrintWriter writer) throws WdkModelException,
            NoSuchAlgorithmException, SQLException, JSONException,
            WdkUserException {
	String lastSequenceId = null;
	for (AnswerValue answerValue : this) {
	    StringBuffer sequenceIdList = new StringBuffer();
	    for (RecordInstance record : answerValue.getRecordInstances()) {
		// Collect the gene ids in this page one by one(?)
		if (sequenceIdList.length() > 0) {
		    sequenceIdList.append(',');
		}
		sequenceIdList.append(record.getAttributeValue("source_id"));
	    }
	    Map<String,String> params = new LinkedHashMap<String,String>();
	    params.put(properties.get(PROPERTY_SEQUENCE_ID_PARAM), sequenceIdList.toString());

	    Map<String,Boolean> sorting = new LinkedHashMap<String,Boolean>();
	    sorting.put(properties.get(PROPERTY_SEQUENCE_ID_COLUMN), true);

	    System.out.println(properties.get(PROPERTY_PAGE_SIZE));
	    System.out.println(Integer.parseInt(properties.get(PROPERTY_PAGE_SIZE)));
	    
	    System.out.println("Running question '" + properties.get(PROPERTY_GENE_QUESTION) + "'");
	    System.out.println("with sequence ids: " + params.get(properties.get(PROPERTY_SEQUENCE_ID_PARAM)));
	    Question geneQuestion = (Question) wdkModel.resolveReference(properties.get(PROPERTY_GENE_QUESTION));
	    AnswerValue geneAnswer = geneQuestion.makeAnswerValue(answerValue.getUser(), params, 0,
								  Integer.parseInt(properties.get(PROPERTY_PAGE_SIZE)), sorting, null, 0);
	    
	    lastSequenceId = writeGenes(geneAnswer, writer, lastSequenceId);
	}
    }

    private String writeGenes(AnswerValue geneAnswer, PrintWriter writer, String lastSequenceId) throws WdkModelException,
            NoSuchAlgorithmException, SQLException, JSONException,
            WdkUserException {
	PageAnswerIterator pagedGenes = new PageAnswerIterator(geneAnswer, 1, geneAnswer.getResultSize());
	while (pagedGenes.hasNext()) {
	    AnswerValue answerValue = pagedGenes.next();
	    
	    for (RecordInstance record : answerValue.getRecordInstances()) {
		String recordSequenceId = record.getAttributeValue(properties.get(PROPERTY_SEQUENCE_ID_COLUMN)).toString();
		if (lastSequenceId != null && lastSequenceId.compareTo(recordSequenceId) != 0) {
		    // If a new sequence id, need to write that out first!
		    writer.println(">Feature\t" + recordSequenceId);
		}
		
		// Write this record out in GenBank Table Format
		// 1. Write gene id & bounds
		// TODO:  Make sure reverse is handled correctly
		writer.print(record.getAttributeValue("start_min"));
		writer.println("\t" + record.getAttributeValue("end_max") + "\tgene");
		writer.println("\t\t\tgene\t" + record.getAttributeValue("source_id"));

		// TODO:  2. CDS bounds & properties
		//        3. (m|t|?)RNA bounds & properties
		String geneType = record.getAttributeValue("gene_type").toString();
		if (geneType.compareTo("protein coding") == 0) geneType = "CDS";

		writer.print(record.getAttributeValue("context_start"));
		writer.println("\t" + record.getAttributeValue("context_end") + "\t" + geneType);
		writer.println("\t\t\tproduct\t" + record.getAttributeValue("product"));

		// TODO:  exons? other features?
		
		lastSequenceId = recordSequenceId;
	    }
	}
	
	return lastSequenceId;
    }
}
