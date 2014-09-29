package org.apidb.apicommon.model.report;

import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.security.NoSuchAlgorithmException;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.WdkUserException;
import org.gusdb.wdk.model.answer.AnswerValue;
import org.gusdb.wdk.model.question.Question;
import org.gusdb.wdk.model.record.RecordInstance;
import org.gusdb.wdk.model.record.TableValue;
import org.gusdb.wdk.model.record.attribute.AttributeValue;
import org.gusdb.wdk.model.report.Reporter;
import org.json.JSONException;

public class GenBankReporter extends Reporter {

    private static final String PROPERTY_GENE_QUESTION = "gene_question";
    private static final String PROPERTY_SEQUENCE_ID_PARAM = "sequence_param";
    private static final String PROPERTY_SEQUENCE_ID_COLUMN = "sequence_id";
    //private static final String CONFIG_SELECTED_COLUMNS = "selectedFields";

    private static final String DB_XREF_QUALIFIER_INTERPRO = "InterPro";
    private static final String DB_XREF_QUALIFIER_NCBI_TAXON = "taxon";
    private static final String DB_XREF_QUALIFIER_ENTREZ_GENE = "GeneID";
    private static final String DB_XREF_QUALIFIER_GOA = "GOA";
    private static final String DB_XREF_QUALIFIER_GI = "GI";
    private static final String DB_XREF_QUALIFIER_UNIPROTKB = "UniProtKB/TrEMBL";

    public GenBankReporter(AnswerValue answerValue, int startIndex, int endIndex) {
        super(answerValue, startIndex, endIndex);
    }

    // Take a sequence question, collect the sequence ids
    // For each page of sequence ids, pass the list of
    // ids to some other question
    // Go through the pages of gene records, writing as
    // genbank table format

    @Override
    public void configure(Map<String, String> newConfig) {
        super.configure(newConfig);
    }

    @Override
    public String getConfigInfo() {
        return "This reporter does not have config info yet.";
    }

    @Override
    protected void write(OutputStream out) throws WdkModelException,
            NoSuchAlgorithmException, SQLException, JSONException,
            WdkUserException {
        String rcName = getQuestion().getRecordClass().getFullName();
        if (!rcName.equals("SequenceRecordClasses.SequenceRecordClass"))
            throw new WdkModelException("Unsupported record type: " + rcName);

        PrintWriter writer = new PrintWriter(new OutputStreamWriter(out));
        pageSequences(writer);
        writer.flush();
    }

    private void pageSequences(PrintWriter writer) throws WdkModelException, WdkUserException {

        for (AnswerValue answerValue : this) {
            for (RecordInstance record : answerValue.getRecordInstances()) {
                String sequenceId = record.getAttributeValue("source_id").toString();

                Map<String, String> params = new LinkedHashMap<String, String>();

                params.put(properties.get(PROPERTY_SEQUENCE_ID_PARAM), sequenceId);

                Map<String, Boolean> sorting = new LinkedHashMap<String, Boolean>();
                sorting.put(properties.get(PROPERTY_SEQUENCE_ID_COLUMN), true);

                String geneQuestionName = properties.get(PROPERTY_GENE_QUESTION);
                Question geneQuestion = (Question) wdkModel.resolveReference(geneQuestionName);
                AnswerValue geneAnswer = geneQuestion.makeAnswerValue(answerValue.getUser(), params, 0,
                                                                      maxPageSize, sorting,  null, true, 0);

                // write non gene sequence features
                writeSequenceFeatures(record, writer);

                // write gene features
                writeTableFormat(geneAnswer, writer, sequenceId);

            }
        }
    }

    private void writeTableFormat(AnswerValue geneAnswer, PrintWriter writer, String sequenceId)
            throws WdkModelException, WdkUserException {

        PageAnswerIterator pagedGenes = new PageAnswerIterator(geneAnswer, 1,
                geneAnswer.getResultSize(), maxPageSize);
        while (pagedGenes.hasNext()) {
            AnswerValue answerValue = pagedGenes.next();

            for (RecordInstance record : answerValue.getRecordInstances()) {
                writeGeneFeature(record, writer, sequenceId);
            }
        }
    }

    private void writeSequenceFeatures(RecordInstance record, PrintWriter writer)
            throws WdkModelException, WdkUserException {
        // Write feature table header w/ sequence id
        writer.println(">Feature\t" + record.getAttributeValue("source_id"));

        // Add non gene features
        writeSimpleGenomicFeature(record, writer, "Repeats");
        writeSimpleGenomicFeature(record, writer, "TandemRepeats");
        //writeSimpleGenomicFeature(record, writer, "LowComplexity");
    }


    private void writeSimpleGenomicFeature(RecordInstance record, PrintWriter writer, String tableString)
            throws WdkModelException, WdkUserException {

        TableValue Rows = record.getTableValue(tableString);
        for (Map<String, AttributeValue> row : Rows) {
            String qualifierKey = row.get("qualifier_key").toString();
            String qualifierValue = row.get("qualifier_value").toString();
            String featureKey = row.get("feature_key").toString();
            String startMin = row.get("start_min").toString();
            String endMax = row.get("end_max").toString();
            writer.println(startMin + "\t" + endMax + "\t" + featureKey + "\t\t");
            if(qualifierKey != null) {
                writer.println("\t\t\t" + qualifierKey + "\t" + qualifierValue);
            }
        }
    }


    private GenBankFeature makeBaseGeneFeature(RecordInstance record, String product)
            throws WdkModelException, WdkUserException {

            String sourceId = record.getAttributeValue("source_id").toString();

            boolean isPseudo = (record.getAttributeValue("is_pseudo").toString().equals("Yes") 
                                || product.toLowerCase().contains(" pseudo "));

            String geneType = record.getAttributeValue("gene_type").toString();
            String sequence;

            if (geneType.equals("protein coding")) {
                sequence = record.getAttributeValue("cds").toString();
            } else {
                sequence = record.getAttributeValue("transcript_sequence").toString();
            }

            String ncbiTaxId = record.getAttributeValue("ncbi_tax_id").toString();

            GenBankFeature geneFeature = new GenBankFeature(sourceId, isPseudo, geneType, "gene", sequence, product);

            geneFeature.addDbXref(DB_XREF_QUALIFIER_NCBI_TAXON + ":" + ncbiTaxId);

            // RULE:  Alias
            TableValue aliasRows = record.getTableValue("Alias");
            for (Map<String, AttributeValue> aliasRow : aliasRows) {
                String alias = aliasRow.get("alias").toString();
                String databaseName = aliasRow.get("database_name").toString();

                // EntrezGene
                if(matchesDatabaseName(databaseName.toLowerCase(), "entrez[_| ]gene"))
                    geneFeature.addDbXref(DB_XREF_QUALIFIER_ENTREZ_GENE + ":" + alias);

                // GOA
                if(matchesDatabaseName(databaseName.toLowerCase(), "goa"))
                    geneFeature.addDbXref(DB_XREF_QUALIFIER_GOA + ":" + alias);

                // GI
                if(matchesDatabaseName(databaseName.toLowerCase(), "_gi_"))
                    geneFeature.addDbXref(DB_XREF_QUALIFIER_GI + ":" + alias);

                // GI
                if(matchesDatabaseName(databaseName.toLowerCase(), "^gi"))
                    geneFeature.addDbXref(DB_XREF_QUALIFIER_GI + ":" + alias);

                // GI
                if(matchesDatabaseName(databaseName.toLowerCase(), "uniprotkb"))
                    geneFeature.addDbXref(DB_XREF_QUALIFIER_UNIPROTKB + ":" + alias);
            }

            return(geneFeature);
    }


    private boolean matchesDatabaseName(CharSequence inputString, String patternString) {

        //        System.out.println(inputString + "\t" + patternString);

        Pattern pattern = Pattern.compile(patternString);
        Matcher matcher = pattern.matcher(inputString);

        return(matcher.find());
    }

    private List<GenBankLocation> makeGenBankLocations(RecordInstance record, String sequenceId)
            throws WdkModelException, WdkUserException {

        TableValue locations = record.getTableValue("GenBankLocations");

        List<GenBankLocation> genbankLocations = new ArrayList<GenBankLocation>();

        for (Map<String, AttributeValue> location : locations) {
            String start = location.get("start_min").toString();
            String end = location.get("end_max").toString();
            String isReversed = location.get("is_reversed").toString();
            String type = location.get("type").toString();
            String sequenceSourceId = location.get("sequence_source_id").toString();

            String strand = isReversed.equals("1") ? "reverse" : "forward";

            if(sequenceId.equals(sequenceSourceId)) {
                GenBankLocation gbLocation = new GenBankLocation(start, end, strand, type);
                genbankLocations.add(gbLocation);
            }
        }
        return(genbankLocations);
    }


    private GenBankCdsFeature makeCdsFeature(RecordInstance record, GenBankFeature geneFeature)
            throws WdkModelException, WdkUserException {

        int codonStart = 0 ;

        // RULE : Include the translation table
        String sequenceSoTerm = record.getAttributeValue("sequence_so_term").toString();
            
        String geneticCode;
        if (sequenceSoTerm.equals("mitochondrial_chromosome")) {
            geneticCode = record.getAttributeValue("mitochondrial_genetic_code").toString();
        } 
        else {
            geneticCode = record.getAttributeValue("genetic_code").toString();
        }
        
        // RULE : Include protein translation for CDS
        String proteinSequence = record.getAttributeValue("protein_sequence").toString();
        String proteinId = record.getAttributeValue("protein_source_id").toString();

        GenBankCdsFeature cdsFeature = new GenBankCdsFeature(geneFeature, proteinSequence, geneticCode, codonStart, proteinId);

        return(cdsFeature);
    }


    private void writeGeneFeature(RecordInstance record, PrintWriter writer, String sequenceId)
            throws WdkModelException, WdkUserException {

        // Exclude Deprecated Genes? or flag them?
        if (!(wdkModel.getProjectId().equals("GiardiaDB")
              && record.getAttributeValue("is_deprecated").toString().equals("Yes"))) {

            String product = record.getAttributeValue("product").toString();

            List<GenBankLocation> genbankLocations = makeGenBankLocations(record, sequenceId);

            GenBankFeature geneFeature = makeBaseGeneFeature(record, product);
            geneFeature.setLocations(genbankLocations);
            writer.print(geneFeature);
            // RULE : Include old locus tag
            // RULE : Include gene synonym

            // mRNA/exon feature can be broken out into separate method if needed
            GenBankFeature exonFeature = new GenBankFeature(geneFeature, "exon");
            exonFeature.setLocations(genbankLocations);
            writer.print(exonFeature);

            // RULE : CDS but not pseudoGene
            if (geneFeature.getSequenceOntology().equals("protein coding") && !geneFeature.getIsPseudo()) {

                GenBankCdsFeature cdsFeature = makeCdsFeature(record, geneFeature);
                cdsFeature.setLocations(genbankLocations);

                // RULE : Include notes
                TableValue comments = record.getTableValue("Notes");
                for (Map<String, AttributeValue> comment : comments) {
                    String commentString = comment.get("comment_string").toString();
                    cdsFeature.addNote(commentString);
                }

                // RULE : SignalP
                TableValue signalPeptideRows = record.getTableValue("SignalP");
                for (Map<String, AttributeValue> signalPeptide  : signalPeptideRows) {
                    String spName = signalPeptide.get("spf_name").toString();
                    String spDScore = signalPeptide.get("d_score").toString();
                    String spHmmSigProb = signalPeptide.get("signal_probability").toString();
                    String spStart = signalPeptide.get("spf_start_min").toString();
                    String spEnd = signalPeptide.get("spf_end_max").toString();

                    String spNote = "SignalP_" + spName + "; d_score=" + spDScore + "; hmm_probability=" +
                        spHmmSigProb + "; protein_start=" + spStart + "; protein_end=" + spEnd;

                    cdsFeature.addNote(spNote);
                }

                // RULE : TMHMM
                TableValue tmhmmRows = record.getTableValue("TMHMM");
                for (Map<String, AttributeValue> tmhmm  : tmhmmRows) {

                    String tmhmmName = tmhmm.get("tmf_name").toString();
                    String tmhmmStart = tmhmm.get("tmf_start_min").toString();
                    String tmhmmEnd = tmhmm.get("tmf_end_max").toString();
                    String tmhmmTopology = tmhmm.get("tmf_topology").toString();

                    String tmhmmNote = "TMHMM_" + tmhmmName + "; topology=" + tmhmmTopology +
                        "; protein_start=" + tmhmmStart + "; protein_end=" + tmhmmEnd;

                    cdsFeature.addNote(tmhmmNote);
                }

                // RULE : Include EC numbers
                try {
                    TableValue ecNumbers = record.getTableValue("EcNumber");
                    for (Map<String, AttributeValue> ecNumber : ecNumbers) {
                        cdsFeature.addEcNumber(ecNumber.get("ec_number").toString());
                    }
                } catch (WdkModelException ex) { }

                // RULE: Add dbxref for Interpro
                TableValue interproRows = record.getTableValue("InterPro");
                for (Map<String, AttributeValue> interproRow : interproRows) {
                    String interproId = interproRow.get("interpro_family_id").toString();
                    if(interproId != null)
                        cdsFeature.addDbXref(DB_XREF_QUALIFIER_INTERPRO + ":" + interproId);
                }
            
                // RULE : Include GO terms as dbxrefs
                try {
                    TableValue goTerms = record.getTableValue("GoTerms");
                    for (Map<String, AttributeValue> goTerm : goTerms) {
                        cdsFeature.addDbXref(goTerm.get("go_id").toString());
                    }
                } catch (WdkModelException ex) { }

                writer.print(cdsFeature);
            }


            // RULE : Provide ncRNA class for ncRNAs
            //if (geneType.equals("ncRNA")) {
            //writer.println("\t\t\t" + "ncRNA_class" + "\t" + "other");
            //}
        }
    }

       @Override
           protected void complete() {
           // do nothing
       }

@Override
    protected void initialize() throws WdkModelException {
    // do nothing
}
}
