/**
 * 
 */
package org.apidb.apicommon.model.report;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;

import javax.sql.DataSource;

import org.apache.log4j.Logger;
import org.gusdb.wdk.model.AttributeField;
import org.gusdb.wdk.model.ColumnAttributeField;
import org.gusdb.wdk.model.FieldScope;
import org.gusdb.wdk.model.LinkAttributeField;
import org.gusdb.wdk.model.PrimaryKeyAttributeField;
import org.gusdb.wdk.model.RecordClass;
import org.gusdb.wdk.model.TableField;
import org.gusdb.wdk.model.TextAttributeField;
import org.gusdb.wdk.model.Utilities;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.WdkUserException;
import org.gusdb.wdk.model.dbms.SqlUtils;
import org.gusdb.wdk.model.query.SqlQuery;
import org.gusdb.wsf.util.BaseCLI;

/**
 * @author xingao, steve fischer
 * 
 *         this command generates the data into detail table.
 * 

 */
public class DetailTableLoader extends BaseCLI {

    private static final String ARG_PROJECT_ID = "model";
    private static final String ARG_SQL_FILE = "sqlFile";
    private static final String ARG_RECORD = "record";
    private static final String ARG_TABLE_FIELD = "field";
    private static final String ARG_DETAIL_TABLE = "detailTable";

    private static final String COLUMN_FIELD_NAME = "field_name";
    private static final String COLUMN_FIELD_TITLE = "field_title";
    private static final String COLUMN_CONTENT = "content";
    private static final String COLUMN_ROW_COUNT = "row_count";

    private static final String FUNCTION_CHAR_CLOB_AGG = "apidb.char_clob_agg";
    private static final String FUNCTION_CLOB_CLOB_AGG = "apidb.clob_clob_agg";

    private static final String PROP_EXCLUDE_FROM_DUMPER = "excludeFromDumper";

    private static final Logger logger = Logger.getLogger(DetailTableLoader.class);

    /**
     * @param args
     * @throws Exception
     */
    public static void main(String[] args) throws Exception {
        String cmdName = System.getProperty("cmdName");
        if (cmdName == null) cmdName = DetailTableLoader.class.getName();
        DetailTableLoader creator = new DetailTableLoader(cmdName,
                "Load a Detail table.  Delete rows that will be replaced");
        try {
            creator.invoke(args);
        } finally {
            System.exit(0);
        }
    }

    private WdkModel wdkModel;
    private DataSource queryDataSource;
    private String detailTable;

    /**
     * @param command
     * @param description
     */
    protected DetailTableLoader(String command, String description) {
        super(command, description);
    }

    protected void declareOptions() {
        addSingleValueOption(ARG_PROJECT_ID, true, null, "The ProjectId, which"
                + " should match the directory name under $GUS_HOME, where "
                + "model-config.xml is stored.");

        addSingleValueOption(ARG_SQL_FILE, true, null, "The file that contains"
                + " a sql that returns the primary key columns of the records");

        addSingleValueOption(ARG_RECORD, true, null, "The full name of the "
                + "record class to be dumped.");

        addSingleValueOption(ARG_DETAIL_TABLE, true, null, "The name of the "
                + "detail table where the cached results are stored.");

        addSingleValueOption(ARG_TABLE_FIELD, false, null, "Optional. A comma"
                + " separated list of the name(s) of the table field(s) to be"
                + " dumped.");
    }

    /*
     * (non-Javadoc)
     * 
     * @see org.gusdb.wsf.util.BaseCLI#invoke()
     */
    @Override
    public void execute() throws Exception {
        long start = System.currentTimeMillis();

        String projectId = (String) getOptionValue(ARG_PROJECT_ID);
        String sqlFile = (String) getOptionValue(ARG_SQL_FILE);
        String recordClassName = (String) getOptionValue(ARG_RECORD);
        detailTable = (String) getOptionValue(ARG_DETAIL_TABLE);
        String fieldNames = (String) getOptionValue(ARG_TABLE_FIELD);

        String gusHome = System.getProperty(Utilities.SYSTEM_PROPERTY_GUS_HOME);
        wdkModel = WdkModel.construct(projectId, gusHome);
        queryDataSource = wdkModel.getQueryPlatform().getDataSource();

        String idSql = loadIdSql(sqlFile);

        RecordClass recordClass = wdkModel.getRecordClass(recordClassName);
        Map<String, TableField> tables = recordClass.getTableFieldMap();
        if (fieldNames != null) { // dump individual table
            // all tables are available in this context
            String[] names = fieldNames.split(",");
            for (String fieldName : names) {
                fieldName = fieldName.trim();
                TableField table = tables.get(fieldName);
                if (table == null)
                    throw new WdkModelException(
                            "The table field doesn't exist: " + fieldName);
                dumpTable(table, idSql);
            }
        } else { // no table specified, only dump tables with a specific flag
            for (TableField table : tables.values()) {
                String[] props = table.getPropertyList(PROP_EXCLUDE_FROM_DUMPER);
                if (props.length > 0 && props[0].equalsIgnoreCase("true"))
                    continue;
                dumpTable(table, idSql);
            }
        }

        long end = System.currentTimeMillis();
        logger.info("totally spent: " + ((end - start) / 1000.0) + " seconds");
    }

    private String loadIdSql(String sqlFile) throws IOException {
        File file = new File(sqlFile);
        StringBuffer sql = new StringBuffer();
        BufferedReader reader = new BufferedReader(new FileReader(file));
        String line;
        while ((line = reader.readLine()) != null) {
            sql.append(line).append("\n");
        }
        reader.close();
        String idSql = sql.toString().trim();
        if (idSql.endsWith(";"))
            idSql = idSql.substring(0, idSql.length() - 1);
        return idSql.trim();
    }

    /**
     * for a given table, it will generate a SQL by joining the original table
     * query with the input idSql, and collapse rows of one record into a clob.
     * 
     * @param table
     * @param idSql
     * @throws WdkModelException
     * @throws SQLException
     * @throws WdkUserException
     */
    private void dumpTable(TableField table, String idSql)
            throws WdkModelException, SQLException, WdkUserException {
        long start = System.currentTimeMillis();

        DataSource updateDataSource = wdkModel.getQueryPlatform().getDataSource();
        Connection updateConnection = updateDataSource.getConnection();

        // Because this is a EuPathDB program, we can assume that the pk
        // has two columns: project and id.
        // the name of the id might differ across record types, so we will
        // not hardcode it, rather put it in a variable called pkName
        String[] pkColumns = table.getRecordClass().getPrimaryKeyAttributeField().getColumnRefs();
        String pkName = pkColumns[0].toUpperCase();
        String pk2 = pkColumns[1].toUpperCase();

        if (!pk2.equals("PROJECT_ID"))
            throw new WdkModelException("Unexpected primary key type: " + pk2);

        String insertSql = "insert into " + detailTable + " (" + pkName
                + ", project_id, field_name, field_title, row_count, content, "
                + " modification_date) values(?,?,?,?,?,?,?)";
        try {
            updateConnection.setAutoCommit(false);
            deleteRows(idSql, table.getName(), updateConnection);

            PreparedStatement insertStmt = updateConnection.prepareStatement(insertSql);
            logger.info("Dumping table [" + table.getName() + "]");
            int[] counts = aggregateLocally(table, idSql, insertStmt,
                    insertSql, pkName);
            updateConnection.commit();

            long end = System.currentTimeMillis();
            logger.info("Dump table [" + table.getName() + "] done.  Inserted "
                    + counts[0] + " (" + counts[1] + " detail) rows in "
                    + ((end - start) / 1000.0) + " seconds");
        } catch (SQLException ex) {
            updateConnection.rollback();
            throw ex;
        } finally {
            if (updateConnection != null) {
                updateConnection.setAutoCommit(true);
                updateConnection.close();
            }
        }
    }

    private void deleteRows(String idSql, String fieldName,
            Connection connection) throws WdkUserException, WdkModelException,
            SQLException {
        StringBuilder sql = new StringBuilder("DELETE FROM " + detailTable);
        sql.append(" WHERE source_id IN (SELECT source_id FROM (");
        sql.append(idSql + "))");
        sql.append(" AND " + COLUMN_FIELD_NAME + "= '" + fieldName + "'");
        logger.info("Removing previous rows:\n" + sql);
        SqlUtils.executeUpdate(wdkModel, connection, sql.toString(),
                "api-report-detail-delete");
    }

    private int[] aggregateLocally(TableField table, String idSql,
            PreparedStatement insertStmt, String insertSql, String pkName)
            throws WdkModelException, SQLException, WdkUserException {

        String title = getTableTitle(table);

        String wrappedSql = getWrappedSql(table, idSql, pkName);

        ResultSet resultSet = SqlUtils.executeQuery(wdkModel, queryDataSource,
                wrappedSql, "api-report-detail-wrapped");
        String srcId = "";
        String prj = "";
        String prevSrcId = "";
        String prevPrj = "";
        StringBuilder aggregatedContent = new StringBuilder();
        int insertCount = 0;
        int detailCount = 0;
        int rowCount = 0;
        boolean first = true;
        while (resultSet.next()) {
            srcId = resultSet.getString(pkName);
            prj = resultSet.getString("PROJECT_ID");
            if (!first && (!srcId.equals(prevSrcId) || !prj.equals(prevPrj))) {
                insertDetailRow(insertStmt, insertSql,
                        aggregatedContent, rowCount, table, prevSrcId,
                        prevPrj, title);
                insertCount++;
                aggregatedContent = new StringBuilder();
                rowCount = 0;
            }
            first = false;
            prevSrcId = srcId;
            prevPrj = prj;

            // aggregate the columns of one row
            String formattedValues[] = formatAttributeValues(resultSet, table);
            if (formattedValues[0] != null)
		aggregatedContent.append(formattedValues[0]);
            for (int i = 1; i < formattedValues.length; i++) {
		if (formattedValues[i] != null)
		    aggregatedContent.append("\t").append(formattedValues[i]);
		else 
		    aggregatedContent.append("\t");
	    }
            aggregatedContent.append("\n");
            rowCount++;
            detailCount++;
        }
	if (aggregatedContent.length() != 0) {
	    insertDetailRow(insertStmt, insertSql, aggregatedContent,
			    rowCount, table, prevSrcId, prevPrj, title);
	    insertCount++;
	}
        int[] counts = { insertCount, detailCount };
        return counts;
    }

    private String getTableTitle(TableField table) {
        StringBuilder title = new StringBuilder();
        title.append("TABLE: ").append(table.getDisplayName()).append("\n");
        boolean firstField = true;
        for (AttributeField attribute : table.getAttributeFields(FieldScope.REPORT_MAKER)) {
            if (firstField) firstField = false;
            else title.append("\t");
            title.append("[").append(attribute.getDisplayName()).append("]");
        }
        return title.toString();
    }

    private String getWrappedSql(TableField table, String idSql, String pkName)
            throws WdkModelException {

        String queryName = table.getQuery().getFullName();
        String tableSql = ((SqlQuery) wdkModel.resolveReference(queryName)).getSql();

        String sql = "select tq.*" + "\n" + "FROM (ID_QUERY) idq," + "\n"
                + "(select tq1.*, rownum as row_num from (TABLE_QUERY) tq1) tq"
                + "\n" + "WHERE idq.project_id = tq.project_id" + "\n"
                + "AND idq.PK_NAME = tq.PK_NAME" + "\n"
                + "ORDER BY tq.PK_NAME, tq.project_id, tq.row_num";
        sql = sql.replace("ID_QUERY", idSql);
        sql = sql.replace("TABLE_QUERY", tableSql);
        sql = sql.replace("PK_NAME", pkName);
	//System.err.println(sql);
        return sql;
    }

    // convert values we get from the database into the displayable format
    // this includes resolving references within text and link attributes
    private String[] formatAttributeValues(ResultSet resultSet, TableField table)
            throws WdkModelException, SQLException, WdkUserException {

        String[] formattedValuesArray = new String[table.getAttributeFields(FieldScope.REPORT_MAKER).length];

        Map<String, String> formattedValuesMap = new HashMap<String, String>();

        int i = 0;
        for (AttributeField attribute : table.getAttributeFields(FieldScope.REPORT_MAKER)) {
            String formattedValue = formatValue(formattedValuesMap, table,
                    attribute, resultSet);
            formattedValuesArray[i++] = formattedValue;
        }
        return formattedValuesArray;
    }

    private String formatValue(Map<String, String> formattedValuesMap,
            TableField table, AttributeField attribute, ResultSet resultSet)
            throws WdkModelException, SQLException, WdkUserException {

        if (formattedValuesMap.containsKey(attribute.getName())) {
            return formattedValuesMap.get(attribute.getName());
        }

        if (attribute instanceof ColumnAttributeField) {
            String value = resultSet.getString(attribute.getName().toUpperCase());
            formattedValuesMap.put(attribute.getName(), value);
            return value;
        }

        String text = null;
        if (attribute instanceof PrimaryKeyAttributeField) {
            text = ((PrimaryKeyAttributeField) attribute).getText();
        } else if (attribute instanceof TextAttributeField) {
            text = ((TextAttributeField) attribute).getText();
        } else if (attribute instanceof LinkAttributeField) {
            text = ((LinkAttributeField) attribute).getDisplayText();
        }

        Collection<AttributeField> children = attribute.getDependents();
        for (AttributeField child : children) {
            String key = "$$" + child.getName() + "$$";
            String childValue = formatValue(formattedValuesMap, table, child,
                    resultSet);
            text = text.replace(key, childValue);
        }
        text = text.trim();
        formattedValuesMap.put(attribute.getName(), text);
        return text;
    }

    /**
     * Aggregate the rows by records, and insert the result into detail table.
     * 
     * @param table
     * @param idSql
     * @throws WdkModelException
     * @throws SQLException
     * @throws WdkUserException
     */
    private void insertDetailRow(PreparedStatement insertStmt,
            String insertSql, StringBuilder contentBuf, int rowCount, TableField table,
            String srcId, String project, String title)
            throws WdkModelException, SQLException, WdkUserException {

	// trim trailing newline (but not leading white space)
	String content = contentBuf.toString().substring(0,contentBuf.length()-1);

        // (source_id, project_id, field_name, field_title, row_count, content,
        // modification_date)
        insertStmt.setString(1, srcId);
        insertStmt.setString(2, project);
        insertStmt.setString(3, table.getName());
        insertStmt.setString(4, title);
        insertStmt.setInt(5, rowCount);
	insertStmt.setString(6, content);
        insertStmt.setDate(7, new java.sql.Date(new java.util.Date().getTime()));
        SqlUtils.executePreparedStatement(wdkModel, insertStmt, insertSql,
                "api-report-detail-insert");
    }

}
