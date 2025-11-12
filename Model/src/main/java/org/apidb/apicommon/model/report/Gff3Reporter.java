package org.apidb.apicommon.model.report;

import static org.gusdb.fgputil.FormatUtil.NL;
import static org.gusdb.fgputil.FormatUtil.urlEncodeUtf8;

import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;
import java.util.regex.PatternSyntaxException;

import javax.sql.DataSource;

import org.apache.log4j.Logger;
import org.gusdb.fgputil.db.SqlUtils;
import org.gusdb.fgputil.db.pool.DatabaseInstance;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.WdkUserException;
import org.gusdb.wdk.model.answer.stream.RecordStream;
import org.gusdb.wdk.model.question.Question;
import org.gusdb.wdk.model.record.RecordClass;
import org.gusdb.wdk.model.record.RecordInstance;
import org.gusdb.wdk.model.record.TableValue;
import org.gusdb.wdk.model.record.attribute.AttributeValue;
import org.gusdb.wdk.model.report.ReporterConfigException;
import org.gusdb.wdk.model.report.config.StandardConfig;
import org.gusdb.wdk.model.report.reporter.PagedAnswerReporter;
import org.json.JSONObject;

/**
 * It takes data from WDK records, and format it into GFF3 format, and it write the GFF content into
 * apidb.GeneDetail table for later use.
 * 
 * @author xingao
 * 
 */
public class Gff3Reporter extends PagedAnswerReporter {

  private static Logger logger = Logger.getLogger(Gff3Reporter.class);

  public static final String PROPERTY_TABLE_CACHE = "table_cache";
  public static final String PROPERTY_PROJECT_ID_COLUMN = "project_id_column";
  public static final String PROPERTY_RECORD_ID_COLUMN = "record_id_column";

  public static final String PROPERTY_GFF_RECORD_NAME = "gff_record";
  public static final String PROPERTY_GFF_TRANSCRIPT_NAME = "gff_transcript";
  public static final String PROPERTY_GFF_PROTEIN_NAME = "gff_protein";

  public final static String FIELD_HAS_TRANSCRIPT = "hasTranscript";
  public final static String FIELD_HAS_PROTEIN = "hasProtein";

  private String tableCache;
  private String recordName;
  private String proteinName;
  private String transcriptName;

  private boolean hasTranscript = false;
  private boolean hasProtein = false;
  private String fileType = "text";

  private PreparedStatement psQuery;

  @Override
  public String getHttpContentType() {
    if (fileType.equalsIgnoreCase("text")) {
      return "text/plain";
    }
    else { // use the default content type defined in the parent class
      return super.getHttpContentType();
    }
  }

  @Override
  public String getDownloadFileName() {
    logger.info("Internal format: " + fileType);
    String name = getQuestion().getName();
    if (fileType.equalsIgnoreCase("text")) {
      return name + ".gff";
    }
    else { // use the default file name defined in the parent
      return super.getDownloadFileName();
    }
  }

  @Override
  public void write(OutputStream out) throws WdkModelException {
    try {
      PrintWriter writer = new PrintWriter(new OutputStreamWriter(out));
  
      // write header
      writeHeader(writer);
  
      // write records
      writeRecords(writer);
  
      // write sequences
      writer.println("##FASTA");
      writeSequences(writer);
    }
    catch (WdkUserException | SQLException e) {
      throw new WdkModelException("Unable to write Gff3 report", e);
    }
  }

  @Override
  protected void initialize() throws WdkModelException {
    // check required properties
    tableCache = _properties.get(PROPERTY_TABLE_CACHE);
    recordName = _properties.get(PROPERTY_GFF_RECORD_NAME);
    proteinName = _properties.get(PROPERTY_GFF_PROTEIN_NAME);
    transcriptName = _properties.get(PROPERTY_GFF_TRANSCRIPT_NAME);

    if (psQuery == null) {
      // prepare the table query
      RecordClass recordClass = _baseAnswer.getQuestion().getRecordClass();
      String[] pkColumns = recordClass.getPrimaryKeyDefinition().getColumnRefs();
      StringBuilder sqlQuery = new StringBuilder("SELECT ");
      sqlQuery.append("count(*) AS cache_count FROM ").append(tableCache);
      sqlQuery.append(" WHERE table_name = ?");
      for (String column : pkColumns) {
        sqlQuery.append(" AND ").append(column).append(" = ?");
      }
      DataSource dataSource = _wdkModel.getAppDb().getDataSource();
      try {
        psQuery = SqlUtils.getPreparedStatement(dataSource, sqlQuery.toString(), SqlUtils.Autocommit.OFF);
      }
      catch (SQLException e) {
        throw new WdkModelException("Unable to initialize reporter.", e);
      }
    }
  }

  @Override
  public Gff3Reporter configure(Map<String, String> newConfig) throws ReporterConfigException {

    if (newConfig.containsKey(StandardConfig.ATTACHMENT_TYPE))
      fileType = newConfig.get(StandardConfig.ATTACHMENT_TYPE);

    // include transcript
    if (newConfig.containsKey(FIELD_HAS_TRANSCRIPT)) {
      String value = newConfig.get(FIELD_HAS_TRANSCRIPT);
      hasTranscript = (value.equalsIgnoreCase("yes") || value.equalsIgnoreCase("true")) ? true : false;
    }

    // include protein
    if (newConfig.containsKey(FIELD_HAS_PROTEIN)) {
      String value = newConfig.get(FIELD_HAS_PROTEIN);
      hasProtein = (value.equalsIgnoreCase("yes") || value.equalsIgnoreCase("true")) ? true : false;
    }

    return this;
  }

  @Override
  public Gff3Reporter configure(JSONObject newConfig) throws ReporterConfigException {

    if (newConfig.has(StandardConfig.ATTACHMENT_TYPE_JSON))
      fileType = newConfig.getString(StandardConfig.ATTACHMENT_TYPE_JSON);

    // include transcript
    if (newConfig.has(FIELD_HAS_TRANSCRIPT))
      hasTranscript = newConfig.getBoolean(FIELD_HAS_TRANSCRIPT);

    // include protein
    if (newConfig.has(FIELD_HAS_PROTEIN))
      hasProtein = newConfig.getBoolean(FIELD_HAS_PROTEIN);

    return this;
  }

  @Override
  protected void complete() {
    if (psQuery != null) {
      SqlUtils.closeStatement(psQuery);
      psQuery = null;
    }
  }

  public String getCacheTable() {
    return tableCache;
  }

  /**
   * The initialize() method has to be called before this method.
   * 
   * @param writer
   * @throws WdkUserException
   */
  void writeHeader(PrintWriter writer) throws WdkModelException, NumberFormatException, WdkUserException {
    writer.println("##gff-version 3");
    writer.println("# feature-ontology so.obo");
    writer.println("# attribute-ontology gff3_attributes.obo");
    writer.flush();

    // get the sequence regions
    Map<String, int[]> regions = new LinkedHashMap<String, int[]>();

    try (RecordStream records = getRecords()) {
      for (RecordInstance record : records) {
        String seqId = getValue(record.getAttributeValue("gff_seqid"));
        int start = Integer.parseInt(getValue(record.getAttributeValue("gff_fstart")));
        int stop = Integer.parseInt(getValue(record.getAttributeValue("gff_fend")));
        if (regions.containsKey(seqId)) {
          int[] region = regions.get(seqId);
          if (region[0] > start)
            region[0] = start;
          if (region[1] < stop)
            region[1] = stop;
          regions.put(seqId, region);
        }
        else {
          int[] region = { start, stop };
          regions.put(seqId, region);
        }
      }
    }

    // put sequence id into the header
    for (String seqId : regions.keySet()) {
      int[] region = regions.get(seqId);
      writer.println("##sequence-region " + seqId + " " + region[0] + " " + region[1]);
    }
    writer.flush();
  }

  /**
   * The initialize() method has to be called before this method.
   * 
   * @param writer
   */
  void writeRecords(PrintWriter writer) throws WdkModelException, SQLException, WdkUserException {
    Question question = getQuestion();
    String rcName = question.getRecordClass().getFullName();
    DatabaseInstance appDb = _wdkModel.getAppDb();

    RecordClass recordClass = question.getRecordClass();
    String[] pkColumns = recordClass.getPrimaryKeyDefinition().getColumnRefs();

    int idx = tableCache.indexOf('.');
    String schema = (idx < 0) ? null : tableCache.substring(0, idx);
    String table = (idx < 0) ? tableCache : tableCache.substring(idx + 1);

    // construct insert sql
    StringBuilder sqlInsert = new StringBuilder("INSERT INTO ");
    sqlInsert.append(tableCache).append(" (wdk_table_id, ");
    sqlInsert.append("table_name, row_count, content");
    for (String column : pkColumns) {
      sqlInsert.append(", ").append(column);
    }
    sqlInsert.append(") VALUES (");
    sqlInsert.append(_wdkModel.getUserDb().getPlatform().getNextIdSqlExpression(schema, table));
    sqlInsert.append(", ");
    sqlInsert.append("?, ?, ?");
    for (int i = 0; i < pkColumns.length; i++) {
      sqlInsert.append(", ?");
    }
    sqlInsert.append(")");

    // check if we need to insert into cache
    PreparedStatement psInsert = null;
    try (RecordStream records = getRecords()) {
      // want to cache the table content
      DataSource dataSource = appDb.getDataSource();
      psInsert = SqlUtils.getPreparedStatement(dataSource, sqlInsert.toString(), SqlUtils.Autocommit.ON);

      for (RecordInstance record : records) {

        StringBuilder recordBuffer = new StringBuilder();

        // read and format record content
        if (rcName.equals("SequenceRecordClasses.SequenceRecordClass")) {
          formatSequenceRecord(record, recordBuffer);
        }
        else if (rcName.equals("GeneRecordClasses.GeneRecordClass")) {
          formatGeneRecord(record, recordBuffer);
        }
        else {
          SqlUtils.closeStatement(psInsert);
          throw new WdkModelException("Unsupported record type: " + rcName);
        }
        String content = recordBuffer.toString();

        // check if needs to insert into cache table
        if (tableCache != null) {
          boolean hasCached = checkCache(record, recordName);
          if (!hasCached) {
            psInsert.setString(1, recordName);
            psInsert.setInt(2, 1);
            appDb.getPlatform().setClobData(psInsert, 3, content, false);
            Map<String, String> pkValues = record.getPrimaryKey().getValues();
            for (int index = 0; index < pkColumns.length; index++) {
              Object value = pkValues.get(pkColumns[index]);
              psInsert.setObject(index + 4, value);
            }
            psInsert.executeUpdate();
          }
        }

        // output the result
        writer.print(content);
        writer.flush();
      }
    }
    finally {
      SqlUtils.closeStatement(psInsert);
    }
  }

  private void formatGeneRecord(RecordInstance record, StringBuilder recordBuffer) throws WdkModelException,
      WdkUserException {
    // get common fields from the record
    readCommonFields(record, recordBuffer);

    // get the rest of the attributes
    String webId = getValue(record.get("gff_attr_web_id"));
    if (webId != null)
      recordBuffer.append(";web_id=" + webId);
    String locusTag = getValue(record.get("gff_attr_locus_tag"));
    if (locusTag != null)
      recordBuffer.append(";locus_tag=" + locusTag);
    String size = getValue(record.get("gff_attr_size"));
    if (size != null)
      recordBuffer.append(";size=" + size);

    // get aliases
    TableValue alias = record.getTableValue("GeneGffAliases");
    StringBuilder sbAlias = new StringBuilder();
    for (Map<String, AttributeValue> row : alias) {
      String alias_value = getValue(row.get("gff_alias")).trim();
      if (sbAlias.length() > 0)
        sbAlias.append(",");
      sbAlias.append(alias_value);
    }
    if (sbAlias.length() > 0)
      recordBuffer.append(";Alias=" + sbAlias.toString());

    recordBuffer.append(NL);

    // get GO terms
    TableValue goTerms = record.getTableValue("GeneGffGoTerms");
    Set<String> termSet = new LinkedHashSet<String>();
    for (Map<String, AttributeValue> row : goTerms) {
      String goTerm = getValue(row.get("gff_go_id")).trim();
      termSet.add(goTerm);
    }
    StringBuilder sbGoTerms = new StringBuilder();
    for (String termName : termSet) {
      if (sbGoTerms.length() > 0)
        sbGoTerms.append(",");
      sbGoTerms.append(termName);
    }

    // get dbxref terms
    TableValue dbxrefs = record.getTableValue("GeneGffDbxrefs");
    StringBuilder sbDbxrefs = new StringBuilder();
    for (Map<String, AttributeValue> row : dbxrefs) {
      String dbxref_value = getValue(row.get("gff_dbxref")).trim();
      if (sbDbxrefs.length() > 0)
        sbDbxrefs.append(",");
      sbDbxrefs.append(dbxref_value);
    }

    // print RNAs
    TableValue rnas = record.getTableValue("GeneGffRnas");
    for (Map<String, AttributeValue> row : rnas) {

      // read common fields
      readCommonFields(row, recordBuffer);

      // read other fields
      recordBuffer.append(";Parent=" + getValue(row.get("gff_attr_parent")));

      // add GO terms in mRNA
      if (sbGoTerms.length() > 0)
        recordBuffer.append(";Ontology_term=" + sbGoTerms.toString());

      // add dbxref in mRNA
      if (sbDbxrefs.length() > 0)
        recordBuffer.append(";Dbxref=" + sbDbxrefs.toString());

      recordBuffer.append(NL);
    }

    // print CDSs
    TableValue cdss = record.getTableValue("GeneGffCdss");
    for (Map<String, AttributeValue> row : cdss) {

      // read common fields
      readCommonFields(row, recordBuffer);

      // read other fields
      recordBuffer.append(";Parent=" + getValue(row.get("gff_attr_parent")));

      recordBuffer.append(NL);
    }

    // print EXONs
    TableValue exons = record.getTableValue("GeneGffExons");
    for (Map<String, AttributeValue> row : exons) {

      // read common fields
      readCommonFields(row, recordBuffer);

      // read other fields
      recordBuffer.append(";Parent=" + getValue(row.get("gff_attr_parent")));

      recordBuffer.append(NL);
    }
  }

  private void formatSequenceRecord(RecordInstance record, StringBuilder recordBuffer)
      throws WdkModelException, WdkUserException {
    // get common fields from the record
    readCommonFields(record, recordBuffer);

    // read other fields
    String webId = getValue(record.get("gff_attr_web_id"));
    if (webId != null)
      recordBuffer.append(";web_id=" + webId);
    recordBuffer.append(";molecule_type=" + getValue(record.get("gff_attr_molecule_type")));
    recordBuffer.append(";organism_name=" + getValue(record.get("gff_attr_organism_name")));
    recordBuffer.append(";translation_table=" + getValue(record.get("gff_attr_translation_table")));
    recordBuffer.append(";topology=" + getValue(record.get("gff_attr_topology")));
    recordBuffer.append(";localization=" + getValue(record.get("gff_attr_localization")));

    // get dbxref terms
    TableValue dbxrefs = record.getTableValue("SequenceGffDbxrefs");
    StringBuilder sbDbxrefs = new StringBuilder();
    for (Map<String, AttributeValue> row : dbxrefs) {
      String dbxref_value = getValue(row.get("gff_dbxref")).trim();
      if (sbDbxrefs.length() > 0)
        sbDbxrefs.append(",");
      sbDbxrefs.append(dbxref_value);
    }
    if (sbDbxrefs.length() > 0)
      recordBuffer.append(";Dbxref=" + sbDbxrefs.toString());

    recordBuffer.append(NL);
  }

  /**
   * The initialize() method has to be called before this method.
   * 
   * @param writer
   */
  void writeSequences(PrintWriter writer) throws WdkModelException, SQLException, WdkUserException {
    Question question = getQuestion();
    String rcName = question.getRecordClass().getFullName();
    DatabaseInstance appDb = _wdkModel.getAppDb();
    RecordClass recordClass = question.getRecordClass();
    String[] pkColumns = recordClass.getPrimaryKeyDefinition().getColumnRefs();

    int idx = tableCache.indexOf('.');
    String schema = (idx < 0) ? null : tableCache.substring(0, idx);
    String table = (idx < 0) ? tableCache : tableCache.substring(idx + 1);

    // construct insert sql
    StringBuilder sqlInsert = new StringBuilder("INSERT INTO ");
    sqlInsert.append(tableCache).append(" (wdk_table_id, ");
    sqlInsert.append("table_name, row_count, content");
    for (String column : pkColumns) {
      sqlInsert.append(", ").append(column);
    }
    sqlInsert.append(") VALUES (");
    sqlInsert.append(_wdkModel.getUserDb().getPlatform().getNextIdSqlExpression(schema, table));
    sqlInsert.append(", ");
    sqlInsert.append("?, ?, ?");
    for (int i = 0; i < pkColumns.length; i++) {
      sqlInsert.append(", ?");
    }
    sqlInsert.append(")");

    // check if we need to insert into cache
    PreparedStatement psInsert = null;
    try (RecordStream records = getRecords()) {
      // want to cache the table content
      DataSource dataSource = appDb.getDataSource();
      psInsert = SqlUtils.getPreparedStatement(dataSource, sqlInsert.toString(), SqlUtils.Autocommit.ON);

      for (RecordInstance record : records) {
        Map<String, String> pkValues = record.getPrimaryKey().getValues();
        // HACK
        String recordId = pkValues.get("source_id");

        // read and format record content
        if (rcName.equals("SequenceRecordClasses.SequenceRecordClass")) {
          // get genome sequence
          String sequence = getValue(record.getAttributeValue("gff_sequence"));
          if (sequence != null && sequence.length() > 0) {
            // output the sequence
            sequence = formatSequence(recordId, sequence);
            writer.print(sequence);
            writer.flush();
          }
        }
        else if (rcName.equals("GeneRecordClasses.GeneRecordClass")) {
          // get transcript, if needed
          if (hasTranscript) {
            String sequence = getValue(record.getAttributeValue("gff_transcript_sequence"));
            if (sequence != null && sequence.length() > 0) {
              sequence = formatSequence(recordId, sequence);

              // check if needs to insert into cache table
              if (tableCache != null) {
                boolean hasCached = checkCache(record, transcriptName);
                if (!hasCached) {
                  psInsert.setString(1, transcriptName);
                  psInsert.setInt(2, 1);
                  appDb.getPlatform().setClobData(psInsert, 3, sequence, false);
                  for (int index = 0; index < pkColumns.length; index++) {
                    Object value = pkValues.get(pkColumns[index]);
                    psInsert.setObject(index + 4, value);
                  }
                  psInsert.executeUpdate();
                }
              }

              // output the sequence
              writer.print(sequence);
              writer.flush();
            }
          }

          // get protein sequence, if needed
          if (hasProtein) {
            // output protein sequence with RNA id
            TableValue rnas = record.getTableValue("GeneGffRnas");
            for (Map<String, AttributeValue> row : rnas) {
              String rnaId = getValue(row.get("gff_attr_id"));
              String sequence = getValue(row.get("gff_protein_sequence"));
              if (rnaId != null && sequence != null && sequence.length() > 0) {
                sequence = formatSequence(rnaId, sequence);

                // check if needs to insert into cache table
                if (tableCache != null) {
                  boolean hasCached = checkCache(record, proteinName);
                  if (!hasCached) {
                    // save into table cache
                    psInsert.setString(1, proteinName);
                    psInsert.setInt(2, 1);
                    appDb.getPlatform().setClobData(psInsert, 3, sequence, false);
                    for (int index = 0; index < pkColumns.length; index++) {
                      Object value = pkValues.get(pkColumns[index]);
                      psInsert.setObject(index + 4, value);
                    }
                    psInsert.executeUpdate();
                  }
                }

                // output the sequence
                writer.print(sequence);
                writer.flush();
              }
            }
          }
        }
        else {
          SqlUtils.closeStatement(psInsert);
          throw new WdkModelException("Unsupported record type: " + rcName);
        }
      }
    }
    finally {
      SqlUtils.closeStatement(psInsert);
    }
  }

  private void readCommonFields(Map<String, AttributeValue> record, StringBuilder buffer) throws WdkModelException,
      WdkUserException {
    buffer.append(getValue(record.get("gff_seqid")) + "\t");
    buffer.append(getValue(record.get("gff_source")) + "\t");
    buffer.append(getValue(record.get("gff_type")) + "\t");
    buffer.append(getValue(record.get("gff_fstart")) + "\t");
    buffer.append(getValue(record.get("gff_fend")) + "\t");
    buffer.append(getValue(record.get("gff_score")) + "\t");
    buffer.append(getValue(record.get("gff_strand")) + "\t");
    buffer.append(getValue(record.get("gff_phase")) + "\t");
    String id = getValue(record.get("gff_attr_id"));
    buffer.append("ID=" + id);

    String name = getValue(record.get("gff_attr_name"));
    if (name == null)
      name = id;
    buffer.append(";Name=" + urlEncodeUtf8(name));

    String description = getValue(record.get("gff_attr_description"));
    if (description == null)
      description = name;
    buffer.append(";description=" + urlEncodeUtf8(description));

    buffer.append(";size=" + getValue(record.get("gff_attr_size")));
  }

  private String getValue(AttributeValue attrVal) throws WdkModelException, WdkUserException {
    String value;
    if (attrVal == null) {
      return null;
    }
    else {
      Object objValue = attrVal.getValue();
      if (objValue == null)
        return null;
      value = objValue.toString();
    }
    value = value.trim();
    if (value.length() == 0)
      return null;
    return value;
  }

  private String formatSequence(String id, String sequence) throws PatternSyntaxException {
    if (sequence == null)
      return null;

    StringBuilder buffer = new StringBuilder();
    buffer.append(">" + id + NL);
    int offset = 0;
    while (offset < sequence.length()) {
      int endp = offset + Math.min(60, sequence.length() - offset);
      buffer.append(sequence.substring(offset, endp) + NL);
      offset = endp;
    }
    return buffer.toString();
  }

  private boolean checkCache(RecordInstance record, String tableName) throws SQLException {
    String[] pkColumns = record.getRecordClass().getPrimaryKeyDefinition().getColumnRefs();
    Map<String, String> pkValues = record.getPrimaryKey().getValues();
    psQuery.setString(1, tableName);
    for (int index = 0; index < pkColumns.length; index++) {
      Object value = pkValues.get(pkColumns[index]);
      psQuery.setObject(index + 2, value);
    }
    ResultSet rs = psQuery.executeQuery();
    try {
      rs.next();
      int count = rs.getInt("cache_count");
      return (count > 0);
    }
    finally {
      rs.close();
    }
  }
}
