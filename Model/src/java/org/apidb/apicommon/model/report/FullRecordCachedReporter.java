/**
 * 
 */
package org.apidb.apicommon.model.report;

import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.security.NoSuchAlgorithmException;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;

import org.apache.log4j.Logger;
import org.gusdb.fgputil.db.SqlUtils;
import org.gusdb.fgputil.db.pool.DatabaseInstance;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.WdkUserException;
import org.gusdb.wdk.model.answer.AnswerValue;
import org.gusdb.wdk.model.record.Field;
import org.gusdb.wdk.model.record.FieldScope;
import org.gusdb.wdk.model.record.RecordClass;
import org.gusdb.wdk.model.record.RecordInstance;
import org.gusdb.wdk.model.record.TableField;
import org.gusdb.wdk.model.record.attribute.AttributeField;
import org.gusdb.wdk.model.record.attribute.AttributeValue;
import org.gusdb.wdk.model.report.StandardReporter;
import org.json.JSONException;

/**
 * @author xingao
 * 
 *         This reporter is used by the WDK "text - Detail" to generate the
 *         report from detail table.
 */
public class FullRecordCachedReporter extends StandardReporter {

    private static Logger logger = Logger.getLogger(FullRecordCachedReporter.class);

    public static final String PROPERTY_TABLE_CACHE = "table_cache";

    private String tableCache;


    public FullRecordCachedReporter(AnswerValue answerValue, int startIndex,
            int endIndex) {
        super(answerValue, startIndex, endIndex);
    }

    /**
     * (non-Javadoc)
     * 
     * @see org.gusdb.wdk.model.report.Reporter#setProperties(java.util.Map)
     */
    @Override
    public void setProperties(Map<String, String> properties)
            throws WdkModelException {
        super.setProperties(properties);

        // check required properties
        tableCache = properties.get(PROPERTY_TABLE_CACHE);

        if (tableCache == null || tableCache.length() == 0)
            throw new WdkModelException("The required property for reporter "
                    + this.getClass().getName() + ", " + PROPERTY_TABLE_CACHE
                    + ", is missing");
    }

    /*
     * (non-Javadoc)
     * 
     * @see org.gusdb.wdk.model.report.Reporter#getHttpContentType()
     */
    @Override
    public String getHttpContentType() {
        if (reporterConfig.getAttachmentType().equalsIgnoreCase("text")) {
            return "text/plain";
        } else { // use the default content type defined in the parent class
            return super.getHttpContentType();
        }
    }

    /*
     * (non-Javadoc)
     * 
     * @see org.gusdb.wdk.model.report.Reporter#getDownloadFileName()
     */
    @Override
    public String getDownloadFileName() {
        logger.info("Internal format: " + reporterConfig.getAttachmentType());
        String name = getQuestion().getName();
        if (reporterConfig.getAttachmentType().equalsIgnoreCase("text")) {
            return name + "_detail.txt";
        } else { // use the defaul file name defined in the parent
            return super.getDownloadFileName();
        }
    }

    /*
     * (non-Javadoc)
     * 
     * @see
     * org.gusdb.wdk.model.report.IReporter#format(org.gusdb.wdk.model.Answer)
     */
    @Override
    public void write(OutputStream out) throws WdkModelException,
            NoSuchAlgorithmException, SQLException, JSONException,
            WdkUserException {
        // get the columns that will be in the report
        Set<Field> fields = validateColumns();

        Set<AttributeField> attributes = new LinkedHashSet<AttributeField>();
        Set<TableField> tables = new LinkedHashSet<TableField>();
        for (Field field : fields) {
            if (field instanceof AttributeField) {
                attributes.add((AttributeField) field);
            } else if (field instanceof TableField) {
                tables.add((TableField) field);
            }
        }

        PrintWriter writer = new PrintWriter(new OutputStreamWriter(out));
        formatRecord2Text(attributes, tables, writer);
        writer.flush();
    }

    private void formatRecord2Text(Set<AttributeField> attributes,
            Set<TableField> tables, PrintWriter writer)
            throws WdkModelException, SQLException, WdkUserException {
        logger.debug("Include empty table: " + reporterConfig.getIncludeEmptyTables());

        RecordClass recordClass = getQuestion().getRecordClass();
        String[] pkColumns = recordClass.getPrimaryKeyAttributeField().getColumnRefs();

        // construct the SQL by join cache table with data table
        StringBuffer sql = new StringBuffer("SELECT ");
        sql.append("field_name, field_title, row_count, content ");
        sql.append("FROM ").append(tableCache);
        for (int index = 0; index < pkColumns.length; index++) {
            sql.append((index == 0) ? " WHERE " : " AND ");
            sql.append(pkColumns[index]).append(" = ?");
        }

        // get the result from database
        DatabaseInstance db = getQuestion().getWdkModel().getAppDb();
        PreparedStatement ps = null;
        try {
            ps = SqlUtils.getPreparedStatement(db.getDataSource(),
                    sql.toString());

            // get page based answers with a maximum size (defined in
            // PageAnswerIterator)
            for (AnswerValue answerValue : this) {
                for (RecordInstance record : answerValue.getRecordInstances()) {
                    // print out attributes of the record first
                    for (AttributeField attribute : attributes) {
                        AttributeValue value = record.getAttributeValue(attribute.getName());
                        writer.println(attribute.getDisplayName() + ": "
                                + value.getValue());
                    }
                    writer.println();
                    writer.flush();

                    // skip he following section if no table field is selected
                    if (tables.size() == 0) continue;

                    // get the cached data of the record
                    Map<String, String> pkValues = record.getPrimaryKey().getValues();
                    for (int index = 0; index < pkColumns.length; index++) {
                        Object value = pkValues.get(pkColumns[index]);
                        ps.setObject(index + 1, value);
                    }
                    ResultSet resultSet = ps.executeQuery();
                    Map<String, String[]> tableValues = new LinkedHashMap<String, String[]>();
                    while (resultSet.next()) {
                        // check if display empty tables
                        int size = resultSet.getInt("row_count");
                        if (!reporterConfig.getIncludeEmptyTables() && size == 0) continue;

                        String fieldName = resultSet.getString("field_name").trim();
                        String fieldTitle = resultSet.getString("field_title").trim();
                        String content = db.getPlatform().getClobData(resultSet,
                                "content");
                        content = (content == null) ? "" : content.trim();
                        tableValues.put(fieldName, new String[] { fieldTitle,
                                content });
                    }
                    resultSet.close();

                    // output the value, preserving the order
                    for (TableField table : tables) {
                        String fieldName = table.getName();
                        if (tableValues.containsKey(fieldName)) {
                            // the table has rows
                            String[] parts = tableValues.get(fieldName);
                            writer.println(parts[0]);
                            writer.println(parts[1]);
                        } else if (reporterConfig.getIncludeEmptyTables()) {
                            // the table doesn't have rows, output title only
                            writer.println(getTableTitle(table));
                        }
                        writer.println();
                        writer.flush();
                    }
                    writer.println();
                    writer.println("------------------------------------------------------------");
                    writer.println();
                    writer.flush();
                }
            }
            writer.flush();
        } finally {
            SqlUtils.closeStatement(ps);
        }
    }

    private String getTableTitle(TableField table) {
        StringBuilder sql = new StringBuilder();
        sql.append("TABLE: ").append(table.getDisplayName()).append("\n");
        boolean firstField = true;
        for (AttributeField attribute : table.getAttributeFields(FieldScope.REPORT_MAKER)) {
            if (firstField) firstField = false;
            else sql.append("\t");
            sql.append("[").append(attribute.getDisplayName()).append("]");
        }
        return sql.toString();
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
