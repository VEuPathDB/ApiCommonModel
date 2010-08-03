/**
 * 
 */
package org.apidb.apicommon.model.report;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.sql.SQLException;
import java.sql.ResultSet;
import java.sql.PreparedStatement;
import java.sql.Date;
//import java.util.Date;
import java.util.Collection;
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
import org.gusdb.wdk.model.dbms.DBPlatform;
import org.gusdb.wdk.model.dbms.SqlUtils;
import org.gusdb.wdk.model.query.SqlQuery;
import org.gusdb.wsf.util.BaseCLI;

/**
 * @author xingao
 * 
 *         this command generates the data into detail table.
 * 
 *         Two Oracle aggregation functions are used. apidb.char_clob_agg(),
 *         input is varchar, and aggregate to clob. It is faster than
 *         apidb.clob_clob_agg(), where the input is already clob. So the first
 *         function is prefered if both can be applied.
 * 
 *         If the concatenated column from a row in the table sql is small
 *         enough (<= 4K), the "clobRow" should be set to false, and
 *         apidb.char_clob_agg() will be used.
 * 
 *         If the table sql already contains clob columns, or if the
 *         concatenated column is too big (> 4K), "clobRow" should be set to
 *         true, otherwise the sql will fail. In this case, a two-step process
 *         will be used with the slower apidb.clob_clob_agg() aggregation
 *         function.
 */
public class DetailTableLoader extends BaseCLI {

    private static final String ARG_PROJECT_ID = "model";
    private static final String ARG_SQL_FILE = "sqlFile";
    private static final String ARG_RECORD = "record";
    private static final String ARG_TABLE_FIELD = "field";
    private static final String ARG_CACHE_TABLE = "cacheTable";

    private static final String COLUMN_FIELD_NAME = "field_name";
    private static final String COLUMN_FIELD_TITLE = "field_title";
    private static final String COLUMN_CONTENT = "content";
    private static final String COLUMN_ROW_COUNT = "row_count";

    private static final String FUNCTION_CHAR_CLOB_AGG = "apidb.char_clob_agg";
    private static final String FUNCTION_CLOB_CLOB_AGG = "apidb.clob_clob_agg";

    private static final String PROP_EXCLUDE_FROM_DUMPER = "excludeFromDumper";

    private static final Logger logger = Logger.getLogger(FullRecordCacheCreator.class);

    /**
     * @param args
     * @throws Exception
     */
    public static void main(String[] args) throws Exception {
        String cmdName = System.getProperty("cmdName");
        if (cmdName == null) cmdName = FullRecordCacheCreator.class.getName();
        FullRecordCacheCreator creator = new FullRecordCacheCreator(cmdName,
                "Create the Dump Table");
        try {
            creator.invoke(args);
        } finally {
            System.exit(0);
        }
    }

    private WdkModel wdkModel;
    private DataSource dataSource;
    private String cacheTable;

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

        addSingleValueOption(ARG_CACHE_TABLE, true, null, "The name of the "
                + "cache table where the cached results are stored.");

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
        cacheTable = (String) getOptionValue(ARG_CACHE_TABLE);
        String fieldNames = (String) getOptionValue(ARG_TABLE_FIELD);

        String gusHome = System.getProperty(Utilities.SYSTEM_PROPERTY_GUS_HOME);
        wdkModel = WdkModel.construct(projectId, gusHome);
        dataSource = wdkModel.getQueryPlatform().getDataSource();
	String insertSql = "insert into " + cacheTable 
	    + " (source_id, project_id, field_name, field_title, row_count, content, modification_date)"
	    + " values(?,?,?,?,?,?,?)"	    ;
	PreparedStatement insertStmt = SqlUtils.getPreparedStatement(dataSource, insertSql);	

        String idSql = loadIdSql(sqlFile);

        deleteRows(idSql, fieldNames);

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
                dumpTable(table, idSql, insertStmt, insertSql);
            }
        } else { // no table specified, only dump tables with a specific flag
            for (TableField table : tables.values()) {
                String[] props = table.getPropertyList(PROP_EXCLUDE_FROM_DUMPER);
                if (props.length > 0 && props[0].equalsIgnoreCase("true"))
                    continue;
                System.out.println(table.getName());
                dumpTable(table, idSql, insertStmt, insertSql);
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
        return idSql;
    }

    private void deleteRows(String idSql, String fieldNames)
            throws WdkUserException, WdkModelException, SQLException {
        StringBuilder sql = new StringBuilder("DELETE FROM " + cacheTable);
        sql.append(" WHERE source_id IN (SELECT source_id FROM (");
        sql.append(idSql + "))");

        if (fieldNames != null) {
            String[] names = fieldNames.split(",");
            sql.append(" AND " + COLUMN_FIELD_NAME + " IN (");
            for (int i = 0; i < names.length; i++) {
                if (i > 0) sql.append(", ");
                sql.append("'" + names[i] + "'");
            }
            sql.append(")");
        }
        SqlUtils.executeUpdate(wdkModel, dataSource, idSql);
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
    private void dumpTable(TableField table, String idSql, PreparedStatement insertStmt, String insertSql)
            throws WdkModelException, SQLException, WdkUserException {
        long start = System.currentTimeMillis();

	aggregateLocally(table, idSql, insertStmt, insertSql);

        long end = System.currentTimeMillis();
        logger.info("Dump table [" + table.getName() + "] used: "
                + ((end - start) / 1000.0) + " seconds");
    }

    private void aggregateLocally(TableField table, String idSql, PreparedStatement insertStmt, String insertSql)
            throws WdkModelException, SQLException, WdkUserException {

	String title = getTableTitle(table) + "\n";

        String idqName = "idq";
        String tqName = "tq";
	String joinedSql = getJoinedSql(table, idSql, idqName, tqName);

        ResultSet resultSet = SqlUtils.executeQuery(wdkModel, dataSource, joinedSql);
	String srcId = "";
	String prj = "";
	String prevSrcId = "";
	String prevPrj = "";
	int colCount = resultSet.getMetaData().getColumnCount();
	StringBuilder aggregatedContent = new StringBuilder(title);
	int rowCount = 0;
	boolean first = true;
	while(resultSet.next()) {
	    srcId = resultSet.getString("SOURCE_ID");
	    prj = resultSet.getString("PROJECT");
	    if (!first && !srcId.equals(prevSrcId) || !prj.equals(prevPrj)) {
		writeDetailRow(insertStmt, insertSql, aggregatedContent.toString(), rowCount, table, srcId, prj, title);
		aggregatedContent = new StringBuilder(title);
		rowCount = 0;
	    }
	    first = false;
	    prevSrcId = srcId;
	    prevPrj = prj;

	    // aggregate the columns of one row
	    aggregatedContent.append(resultSet.getString(0));	    
	    for (int i=1; i<colCount;i++) 
		aggregatedContent.append("\t").append(resultSet.getString(i));
	    aggregatedContent.append("\n");	    
	    rowCount++;
	}
	writeDetailRow(insertStmt, insertSql, aggregatedContent.toString(), rowCount, table, srcId, prj, title);
    } 

    /**
     * Construct the FROM and WHERE clauses from the table SQL and given id SQL.
     * 
     * @param table
     * @param idSql
     * @param idqName
     * @param tqName
     * @return
     * @throws WdkModelException
     */
    private String getJoinedSql(TableField table, String idSql, String idqName,
            String tqName) throws WdkModelException {
        String queryName = table.getQuery().getFullName();
        String tableSql = ((SqlQuery) wdkModel.resolveReference(queryName)).getSql();
        String[] pkColumns = table.getRecordClass().getPrimaryKeyAttributeField().getColumnRefs();
        StringBuilder sql = new StringBuilder(" FROM ");
        sql.append('(').append(idSql).append(") ").append(idqName);
        sql.append(", (").append(tableSql).append(") ").append(tqName);
        boolean firstColumn = true;
        for (String column : pkColumns) {
            if (firstColumn) {
                sql.append(" WHERE ");
                firstColumn = false;
            } else sql.append(" AND ");
            sql.append(idqName).append(".").append(column).append(" = ");
            sql.append(tqName).append(".").append(column);
        }
        return sql.toString();
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
    private void writeDetailRow(PreparedStatement insertStmt, String insertSql, String content, int rowCount, TableField table, String srcId, String project, String title)
            throws WdkModelException, SQLException, WdkUserException {
	// (source_id, project_id, field_name, field_title, row_count, content, modification_date)
	insertStmt.setString(1,srcId);
	insertStmt.setString(2,project);
	insertStmt.setString(3,table.getName());
	insertStmt.setString(4,title);
	insertStmt.setInt(5,rowCount);
	insertStmt.setString(6,content);
	insertStmt.setDate(7, new java.sql.Date(new java.util.Date().getTime()));
        SqlUtils.executePreparedStatement(wdkModel, insertStmt, insertSql);
    }

    /**
     * construct the SELECT clause for the final INSERT sql.
     * 
     * @param table
     * @param pkColumns
     * @return
     */
    private String getSelectSql(TableField table, String pkColumns) {
        String name = table.getName();
        String title = getTableTitle(table);
        StringBuffer sql = new StringBuffer(" SELECT ");
        sql.append(pkColumns).append(", '");
        sql.append(name).append("' AS ").append(COLUMN_FIELD_NAME).append(',');
        sql.append(title).append(" AS ").append(COLUMN_FIELD_TITLE).append(',');
        sql.append("count(*) AS ").append(COLUMN_ROW_COUNT).append(' ');
        return sql.toString();
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
        String title = sql.toString().replace("'", "''");
        return "'" + title + "'";
    }

    /**
     * Concatenate columns in the table SQL into one big column.
     * 
     * If the clobRow is set to true, I'll convert the first column to clob,
     * then do the concatenation. Oracle will use CLOB as the type of the
     * concatenated column; otherwise, it will be a varchar.
     * 
     * @param tableName
     * @param table
     * @return
     * @throws WdkModelException
     */
    private String getAttributesContentSql(String tableName, TableField table)
            throws WdkModelException {
        StringBuilder sql = new StringBuilder();
        boolean clobRow = ((SqlQuery) table.getQuery()).isClobRow();
        for (AttributeField attribute : table.getAttributeFields(FieldScope.REPORT_MAKER)) {
            String attributeSql = getAttributeContentSql(tableName, attribute);
            if (clobRow && sql.length() == 0) {
                attributeSql = "TO_CLOB(" + attributeSql + ")";
            } else if (sql.length() > 0) sql.append(" || '\t' || ");
            sql.append(attributeSql);
        }
        return sql.toString();
    }

    private String getAttributeContentSql(String tableName,
            AttributeField attribute) throws WdkModelException {
        if (attribute instanceof ColumnAttributeField)
            return tableName + "." + attribute.getName();

        String text = null;
        if (attribute instanceof PrimaryKeyAttributeField) {
            text = ((PrimaryKeyAttributeField) attribute).getText();
        } else if (attribute instanceof TextAttributeField) {
            text = ((TextAttributeField) attribute).getText();
        } else if (attribute instanceof LinkAttributeField) {
            text = ((LinkAttributeField) attribute).getDisplayText();
        }
        text = "'" + text.replace("'", "''") + "'";
        Collection<AttributeField> children = attribute.getDependents();
        for (AttributeField child : children) {
            String key = "$$" + child.getName() + "$$";
            String replace = getAttributeContentSql(tableName, child);
            text = text.replace(key, "' || " + replace + " || '");
        }
        if (text.startsWith("'' || ")) text = text.substring(6);
        if (text.endsWith(" || ''"))
            text = text.substring(0, text.length() - 6);
        return text.trim();
    }
}
