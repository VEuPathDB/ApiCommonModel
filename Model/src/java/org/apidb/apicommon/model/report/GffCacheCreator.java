/**
 * 
 */
package org.apidb.apicommon.model.report;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.sql.SQLException;

import javax.sql.DataSource;

import org.apache.log4j.Logger;
import org.gusdb.fgputil.db.SqlUtils;
import org.gusdb.wdk.model.Utilities;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.WdkUserException;
import org.gusdb.wdk.model.query.SqlQuery;
import org.gusdb.wdk.model.record.RecordClass;
import org.gusdb.wsf.util.BaseCLI;

/**
 * @author ctreatma
 * 
 * have problem with clobs, will be removed in the future
 */
@Deprecated
public class GffCacheCreator extends BaseCLI {
    private static final String NEW_LINE = System.getProperty("line.separator");

    private static final String ARG_CACHE_TABLE = "cacheTable";
    private static final String ARG_PROJECT_ID = "model";
    private static final String ARG_SQL_FILE = "sqlFile";

    private static final String ARG_GFF_RECORD_NAME = "gff_record";
    private static final String ARG_GFF_TRANSCRIPT_NAME = "gff_transcript";
    private static final String ARG_GFF_PROTEIN_NAME = "gff_protein";

    private static final String COLUMN_TABLE_NAME = "table_name";
    private static final String COLUMN_CONTENT = "content";
    private static final String COLUMN_ROW_COUNT = "row_count";
    private static final String COLUMN_MODIFICATION_DATE = "modification_date";
    private static final String COLUMN_WDK_TABLE_ID = "wdk_table_id";

    //private static final String COLUMN_GO_ID = "go_id";
    private static final String COLUMN_ONTOLOGY = "ontology";
    private static final String COLUMN_ORDER_NUMBER = "order_number";
    private static final String COLUMN_GFF_SEQID = "gff_seqid";
    private static final String COLUMN_GFF_SOURCE = "gff_source";
    private static final String COLUMN_GFF_TYPE = "gff_type";
    private static final String COLUMN_GFF_FSTART = "gff_fstart";
    private static final String COLUMN_GFF_FEND = "gff_fend";
    private static final String COLUMN_GFF_SCORE = "gff_score";
    private static final String COLUMN_GFF_STRAND = "gff_strand";
    private static final String COLUMN_GFF_PHASE = "gff_phase";
    private static final String COLUMN_GFF_ALIAS = "gff_alias";
    private static final String COLUMN_GFF_ATTR_ID = "gff_attr_id";
    private static final String COLUMN_GFF_ATTR_NAME = "gff_attr_name";
    private static final String COLUMN_GFF_ATTR_DESCRIPTION = "gff_attr_description";
    private static final String COLUMN_GFF_ATTR_SIZE = "gff_attr_size";
    private static final String COLUMN_GFF_ATTR_LOCUS_TAG = "gff_attr_locus_tag";
    private static final String COLUMN_GFF_ATTR_PARENT = "gff_attr_parent";
    private static final String COLUMN_GFF_ATTR_WEB_ID = "source_id";
    private static final String COLUMN_GFF_GO_ID = "gff_go_id";
    private static final String COLUMN_GFF_DBXREF = "gff_dbxref";
    private static final String COLUMN_GFF_TRANSCRIPT_SEQUENCE = "gff_transcript_sequence";
    private static final String COLUMN_GFF_PROTEIN_SEQUENCE = "gff_protein_sequence";
    private static final String COLUMN_SOURCE_ID = "source_id";

    private static final String GENE_RECORD_CLASS = "GeneRecordClasses.GeneRecordClass"; // Is
    // this ok?
    //private static final String GENE_TABLE_QUERIES = "GeneTables";
    private static final String TABLE_GENE_GFF_RNAS = "GeneGffRnas";
    private static final String TABLE_GENE_GFF_CDSS = "GeneGffCdss";
    private static final String TABLE_GENE_GFF_EXONS = "GeneGffExons";
    private static final String TABLE_GENE_GFF_ALIASES = "GeneGffAliases";
    private static final String TABLE_GENE_GFF_GO_TERMS = "GeneGffGoTerms";
    private static final String TABLE_GENE_GFF_DBXREFS = "GeneGffDbxrefs";

    private static final Logger logger = Logger.getLogger(FullRecordCacheCreator.class);

    /**
     * @param args
     * @throws Exception
     */
    public static void main(String[] args) throws Exception {
        String cmdName = System.getProperty("cmdName");
        if (cmdName == null) cmdName = GffCacheCreator.class.getName();
        GffCacheCreator creator = new GffCacheCreator(cmdName,
                "Create the Gene GFF Dump Table");
        try {
            creator.invoke(args);
        } finally {
            System.exit(0);
        }
    }

    private WdkModel wdkModel;
    private RecordClass recordClass;
    private String cacheTable;
    private String recordName;
    private String proteinName;
    private String transcriptName;

    public GffCacheCreator(String command, String description) {
        super(command, description);
    }

    protected void declareOptions() {
        addSingleValueOption(ARG_PROJECT_ID, true, null, "The ProjectId, which"
                + " should match the directory name under $GUS_HOME, where "
                + "model-config.xml is stored.");

        addSingleValueOption(ARG_CACHE_TABLE, true, null, "The name of the "
                + "cache table where the cached results are stored.");

        addSingleValueOption(ARG_SQL_FILE, true, null, "The file that contains"
                + " a sql that returns the primary key columns of the records");

        addSingleValueOption(ARG_GFF_RECORD_NAME, true, null,
                "The table name for " + "the record entry in the cache table.");

        addSingleValueOption(
                ARG_GFF_TRANSCRIPT_NAME,
                true,
                null,
                "The table name for "
                        + "the transcript (NA sequence) entry in the cache table.");

        addSingleValueOption(ARG_GFF_PROTEIN_NAME, true, null,
                "The table name for "
                        + "the protein (AA sequence) entry in the cache table.");
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
        cacheTable = (String) getOptionValue(ARG_CACHE_TABLE);
        recordName = (String) getOptionValue(ARG_GFF_RECORD_NAME);
        transcriptName = (String) getOptionValue(ARG_GFF_TRANSCRIPT_NAME);
        proteinName = (String) getOptionValue(ARG_GFF_PROTEIN_NAME);

        String gusHome = System.getProperty(Utilities.SYSTEM_PROPERTY_GUS_HOME);
        wdkModel = WdkModel.construct(projectId, gusHome);

        recordClass = wdkModel.getRecordClass(GENE_RECORD_CLASS);

        String idSql = loadIdSql(sqlFile);

        deleteRows(idSql);
        dumpGeneAttributes(idSql);
        dumpTranscript(idSql);
        dumpProteinSequence(idSql);

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

    private void deleteRows(String idSql) throws SQLException,
            WdkModelException, WdkUserException {
        StringBuffer sql = new StringBuffer("DELETE FROM " + cacheTable);
        sql.append(" WHERE source_id IN (SELECT source_id FROM (");
        sql.append(idSql + "))");

        DataSource dataSource = wdkModel.getAppDb().getDataSource();
        SqlUtils.executeUpdate(dataSource, sql.toString(),
                "api-report-gff-delete");
    }

    private void insertToCacheTable(String subquerySql) throws SQLException,
            WdkModelException, WdkUserException {
        StringBuffer sql = new StringBuffer("INSERT INTO " + cacheTable);
        sql.append(" (" + COLUMN_SOURCE_ID + ", project_id, "
                + COLUMN_TABLE_NAME + ", " + COLUMN_ROW_COUNT + ", "
                + COLUMN_CONTENT + ", " + COLUMN_WDK_TABLE_ID + ", "
                + COLUMN_MODIFICATION_DATE + ") ");
        sql.append(subquerySql);
        logger.debug("++++++ insert-to-cache-table: \n" + sql);
        DataSource dataSource = wdkModel.getAppDb().getDataSource();
        SqlUtils.executeUpdate(dataSource, sql.toString(),
                "api-report-gff-insert");
    }

    private void dumpGeneAttributes(String idSql) throws SQLException,
            WdkModelException, WdkUserException {
        String idqName = "idq";
        String aliasTable = "gffalias";
        String rnaTable = "gffrna";
        String cdsTable = "gffcds";
        String exonTable = "gffexon";
        String attributeTable = "gffattr";

        StringBuffer sql = new StringBuffer("SELECT ");

        getSelectPkColumns(sql, attributeTable);

        getTableNameRowCountSql(sql, recordName);

        // Dump column fields (no parent)
        addCommonFieldsSql(sql, false);

        // Dump gff_attr_web_id
        sql.append(" || trim(DECODE(").append(attributeTable).append('.').append(
                COLUMN_GFF_ATTR_WEB_ID).append(", NULL, to_clob(''), ");
        sql.append(" to_clob(';web_id=') || ").append(attributeTable).append('.').append(
                COLUMN_GFF_ATTR_WEB_ID).append("))");
        // Dump gff_attr_locus_tag
        sql.append(" || trim(DECODE(").append(COLUMN_GFF_ATTR_LOCUS_TAG).append(
                ", NULL, to_clob(''), ");
        sql.append(" to_clob(';locus_tag=') || ").append(COLUMN_GFF_ATTR_LOCUS_TAG).append(
                "))");
        // Dump gff_attr_size
        sql.append(" || trim(DECODE(").append(COLUMN_GFF_ATTR_SIZE).append(
                ", NULL, to_clob(''), ");
        sql.append(" to_clob(';size=') || ").append(COLUMN_GFF_ATTR_SIZE).append("))");

        // Dump Aliases
        sql.append(" || DECODE(").append(aliasTable).append('.').append(
                COLUMN_CONTENT).append(", NULL, to_clob(''), ");
        sql.append(" to_clob(';Alias=') || ").append(aliasTable).append('.').append(
                COLUMN_CONTENT).append(") || '").append(NEW_LINE).append("' ");

        // Dump RNAs (incl. go terms & dbxref)
        sql.append(" || DECODE(").append(rnaTable).append('.').append(
                COLUMN_CONTENT).append(", NULL, to_clob(''), ");
        sql.append(rnaTable).append('.').append(COLUMN_CONTENT).append(" || '").append(
                NEW_LINE).append("') ");

        // Dump CDSs
        sql.append(" || DECODE(").append(cdsTable).append('.').append(
                COLUMN_CONTENT).append(", NULL, to_clob(''), ");
        sql.append(cdsTable).append('.').append(COLUMN_CONTENT).append(" || '").append(
                NEW_LINE).append("') ");

        // Dump exons
        sql.append(" || DECODE(").append(exonTable).append('.').append(
                COLUMN_CONTENT).append(", NULL, to_clob(''), ");
        sql.append(exonTable).append('.').append(COLUMN_CONTENT).append(" || '").append(
                NEW_LINE).append("') ");

        sql.append(" AS ").append(COLUMN_CONTENT).append(',');

        getTableIdModificationDateSql(sql);

        sql.append(" FROM (");

        // Bring in attribute query
        sql.append(((SqlQuery) wdkModel.resolveReference("GeneAttributes.GeneGffAttrs")).getSql());
        sql.append(") ").append(attributeTable).append(" LEFT OUTER JOIN (");

        // Bring in alias table query
        dumpAliases(sql);
        sql.append(") ").append(aliasTable);

        getJoinPkColumns(sql, attributeTable, aliasTable, true, true);

        // Bring in RNA table query
        sql.append(" LEFT OUTER JOIN (");
        dumpRnaTable(sql);
        sql.append(") ").append(rnaTable);

        getJoinPkColumns(sql, attributeTable, rnaTable, true, true);

        // Bring in CDS table query
        sql.append(" LEFT OUTER JOIN (");
        dumpCdsTable(sql);
        sql.append(") ").append(cdsTable);

        getJoinPkColumns(sql, attributeTable, cdsTable, true, true);

        // Bring in exon table query
        sql.append(" LEFT OUTER JOIN (");
        dumpExonTable(sql);
        sql.append(") ").append(exonTable);
        getJoinPkColumns(sql, attributeTable, exonTable, true, true);

        // Join to id query
        sql.append(',');
        sql.append('(').append(idSql).append(") ").append(idqName);
        getJoinPkColumns(sql, idqName, attributeTable, false, true);

        insertToCacheTable(sql.toString());
    }

    private void dumpRnaTable(StringBuffer sql) throws WdkModelException {
        String queryName = "grna";
        String goSubQueryName = "ggo";
        String dbxrefSubQueryName = "gdbx";

        sql.append("SELECT ");

        getSelectPkColumns(sql, null);

        sql.append("apidb.tab_to_string(set(cast(COLLECT(trim(to_char(");

        sql.append(COLUMN_CONTENT);

        sql.append("))) AS apidb.varchartab)), '").append(NEW_LINE).append(
                "') AS ").append(COLUMN_CONTENT).append(" FROM (");

        sql.append("SELECT ");

        getSelectPkColumns(sql, queryName);

        // read common fields
        addCommonFieldsSql(sql, true);

        // add GO terms in mRNA
        sql.append(" || DECODE(").append(goSubQueryName).append('.').append(
                COLUMN_CONTENT).append(", NULL, to_clob(''), to_clob(';Ontology_term=') || ").append(
                goSubQueryName).append(".").append(COLUMN_CONTENT).append(") ");

        // add dbxref in mRNA
        sql.append(" || DECODE(").append(dbxrefSubQueryName).append('.').append(
                COLUMN_CONTENT).append(", NULL, to_clob(''), to_clob(';Dbxref=') || ").append(
                dbxrefSubQueryName).append(".").append(COLUMN_CONTENT).append(
                ") AS ").append(COLUMN_CONTENT).append(" FROM (");

        // rna table query
        String tqueryName = recordClass.getTableFieldMap().get(
                TABLE_GENE_GFF_RNAS).getQuery().getFullName();
        sql.append(((SqlQuery) wdkModel.resolveReference(tqueryName)).getSql());

        sql.append(") ").append(queryName).append(" LEFT OUTER JOIN (");

        // go term query
        dumpGoTerms(sql);
        sql.append(") ").append(goSubQueryName);

        // join conditions
        getJoinPkColumns(sql, queryName, goSubQueryName, true, true);

        sql.append(" LEFT OUTER JOIN (");
        // dbxref query
        dumpDbxrefs(sql);
        sql.append(") ").append(dbxrefSubQueryName);

        // join conditions
        getJoinPkColumns(sql, queryName, dbxrefSubQueryName, true, true);

        sql.append(')');

        getGroupPkColumns(sql, null);
    }

    private void dumpCdsTable(StringBuffer sql) throws WdkModelException {
        dumpTableAsContent(sql, TABLE_GENE_GFF_CDSS);
    }

    private void dumpExonTable(StringBuffer sql) throws WdkModelException {
        dumpTableAsContent(sql, TABLE_GENE_GFF_EXONS);
    }

    private void dumpTableAsContent(StringBuffer sql, String tableName)
            throws WdkModelException {
        sql.append("SELECT ");

        getSelectPkColumns(sql, null);

        sql.append("apidb.tab_to_string(set(cast(COLLECT(trim(to_char(");

        sql.append(COLUMN_CONTENT);

        sql.append(")) ORDER BY ").append(COLUMN_ORDER_NUMBER).append(
                ") AS apidb.varchartab)), '").append(NEW_LINE).append("') AS ").append(
                COLUMN_CONTENT).append(" FROM (");

        sql.append("SELECT ");

        getSelectPkColumns(sql, null);

        addCommonFieldsSql(sql, true);

        sql.append(" AS ").append(COLUMN_CONTENT).append(',').append(
                COLUMN_ORDER_NUMBER).append(" FROM (");

        // table query
        String queryName = recordClass.getTableFieldMap().get(tableName).getQuery().getFullName();
        String tableQuerySql = ((SqlQuery) wdkModel.resolveReference(queryName)).getSql();

        sql.append(tableQuerySql.substring(0,
                tableQuerySql.toLowerCase().indexOf("gf.source_id,")));
        sql.append(COLUMN_ORDER_NUMBER).append(',').append(
                tableQuerySql.substring(tableQuerySql.toLowerCase().indexOf(
                        "gf.source_id,")));

        sql.append("))");

        getGroupPkColumns(sql, null);
    }

    private void dumpAliases(StringBuffer sql) throws WdkModelException {
        dumpAttributeAsListSql(sql, COLUMN_GFF_ALIAS, TABLE_GENE_GFF_ALIASES,
                false, "");
    }

    private void dumpGoTerms(StringBuffer sql) throws WdkModelException {
        sql.append("SELECT ");

        getSelectPkColumns(sql, null);

        sql.append("apidb.tab_to_string(set(cast(COLLECT(trim(to_char(");

        sql.append(COLUMN_GFF_GO_ID);

        sql.append(")) ORDER BY ").append(COLUMN_ONTOLOGY).append(",").append(
                COLUMN_GFF_GO_ID).append(") AS apidb.varchartab)), ',') AS ").append(
                COLUMN_CONTENT).append(" FROM (");

        sql.append("SELECT ");

        getSelectPkColumns(sql, null);

        sql.append(COLUMN_GFF_GO_ID).append(",").append(COLUMN_ONTOLOGY).append(
                " FROM (");
        // table query
        String queryName = recordClass.getTableFieldMap().get(
                TABLE_GENE_GFF_GO_TERMS).getQuery().getFullName();
        String tableQuerySql = ((SqlQuery) wdkModel.resolveReference(queryName)).getSql();

        sql.append(tableQuerySql.substring(0,
                tableQuerySql.toLowerCase().indexOf("from")));
        sql.append(",").append(COLUMN_ONTOLOGY).append(" ").append(
                tableQuerySql.substring(tableQuerySql.toLowerCase().indexOf(
                        "from")));

        sql.append(")");
        getGroupPkColumns(sql, null);
        sql.append(",").append(COLUMN_GFF_GO_ID);
        sql.append(",").append(COLUMN_ONTOLOGY);

        sql.append(")");
        getGroupPkColumns(sql, null);
    }

    private void dumpDbxrefs(StringBuffer sql) throws WdkModelException {
        dumpAttributeAsListSql(sql, COLUMN_GFF_DBXREF, TABLE_GENE_GFF_DBXREFS,
                false, "ORDER BY " + COLUMN_GFF_DBXREF);
    }

    private void dumpAttributeAsListSql(StringBuffer sql, String columnName,
            String tableName, boolean groupInnerQuery, String collectOrder)
            throws WdkModelException {
        sql.append("SELECT ");

        getSelectPkColumns(sql, null);

        sql.append("apidb.tab_to_string(set(cast(COLLECT(trim(to_char(");

        sql.append(columnName);

        sql.append(")) ").append(collectOrder).append(
                ") AS apidb.varchartab)), ',') AS ").append(COLUMN_CONTENT).append(
                " FROM (");

        sql.append("SELECT ");

        getSelectPkColumns(sql, null);

        sql.append(columnName).append(" FROM (");
        // table query
        String queryName = recordClass.getTableFieldMap().get(tableName).getQuery().getFullName();
        sql.append(((SqlQuery) wdkModel.resolveReference(queryName)).getSql());

        sql.append(")");
        getGroupPkColumns(sql, null);
        sql.append(",").append(columnName);

        sql.append(")");
        getGroupPkColumns(sql, null);
    }

    private void dumpTranscript(String idSql) throws SQLException,
            WdkModelException, WdkUserException {
        String idqName = "idq";
        String seqQueryName = "seq";
        StringBuffer sql = new StringBuffer("SELECT ");

        getSelectPkColumns(sql, seqQueryName);

        getTableNameRowCountSql(sql, transcriptName);

        sql.append("apidb.gff_format_sequence(").append(seqQueryName).append(
                '.');
        sql.append(COLUMN_SOURCE_ID).append(',').append(
                COLUMN_GFF_TRANSCRIPT_SEQUENCE);
        sql.append(") AS ").append(COLUMN_CONTENT).append(',');

        getTableIdModificationDateSql(sql);

        sql.append(" FROM (");
        sql.append(((SqlQuery) wdkModel.resolveReference("GeneAttributes.GeneGffSequence")).getSql());
        sql.append(')').append(seqQueryName).append(',');
        sql.append('(').append(idSql).append(") ").append(idqName);
        getJoinPkColumns(sql, idqName, seqQueryName, false, true);

        insertToCacheTable(sql.toString());
    }

    private void dumpProteinSequence(String idSql) throws SQLException,
            WdkModelException, WdkUserException {
        String idqName = "idq";
        String cdsQueryName = "cds";
        String rnaQueryName = "rna";
        String cdsSubqueryName = "subcds";

        StringBuffer sql = new StringBuffer("SELECT ");

        getSelectPkColumns(sql, rnaQueryName);

        getTableNameRowCountSql(sql, proteinName);

        sql.append("apidb.gff_format_sequence(").append(cdsQueryName).append(
                '.').append(COLUMN_GFF_ATTR_ID);
        sql.append(", ").append(rnaQueryName).append(".").append(
                COLUMN_GFF_PROTEIN_SEQUENCE);
        sql.append(") AS ").append(COLUMN_CONTENT).append(",");

        getTableIdModificationDateSql(sql);

        sql.append(" FROM (");
        String queryName = recordClass.getTableFieldMap().get(
                TABLE_GENE_GFF_RNAS).getQuery().getFullName();
        sql.append(((SqlQuery) wdkModel.resolveReference(queryName)).getSql());
        sql.append(") ").append(rnaQueryName).append(", (SELECT ");

        getSelectPkColumns(sql, cdsSubqueryName);

        sql.append("min(").append(cdsSubqueryName).append(".").append(
                COLUMN_GFF_ATTR_ID).append(") AS ");
        sql.append(COLUMN_GFF_ATTR_ID).append(" FROM (");
        queryName = recordClass.getTableFieldMap().get(TABLE_GENE_GFF_CDSS).getQuery().getFullName();
        sql.append(((SqlQuery) wdkModel.resolveReference(queryName)).getSql());
        sql.append(") ").append(cdsSubqueryName);

        getGroupPkColumns(sql, cdsSubqueryName);

        sql.append(") ").append(cdsQueryName).append(',');
        sql.append('(').append(idSql).append(") ").append(idqName);

        getJoinPkColumns(sql, idqName, rnaQueryName, false, true);
        getJoinPkColumns(sql, cdsQueryName, rnaQueryName, false, false);

        sql.append(" AND ").append(COLUMN_GFF_PROTEIN_SEQUENCE).append(
                " IS NOT NULL ");

        insertToCacheTable(sql.toString());
    }

    private void addCommonFieldsSql(StringBuffer sql, boolean includeParent) {
        // always convert the first column to clob, so that the concatenation
        // won't fail if the content is too long.
        sql.append("to_clob(trim(").append(COLUMN_GFF_SEQID).append(
                ")) || '\t' || ");
        sql.append("trim(").append(COLUMN_GFF_SOURCE).append(") || '\t' || ");
        sql.append("trim(").append(COLUMN_GFF_TYPE).append(") || '\t' || ");
        sql.append("trim(").append(COLUMN_GFF_FSTART).append(") || '\t' || ");
        sql.append("trim(").append(COLUMN_GFF_FEND).append(") || '\t' || ");
        sql.append("trim(").append(COLUMN_GFF_SCORE).append(") || '\t' || ");
        sql.append("trim(").append(COLUMN_GFF_STRAND).append(") || '\t' || ");
        sql.append("trim(").append(COLUMN_GFF_PHASE).append(") || '\t' || ");
        sql.append(" 'ID=' || trim(").append(COLUMN_GFF_ATTR_ID).append(")");

        sql.append(" || ';Name=' || apidb.url_escape(trim(COALESCE(").append(
                COLUMN_GFF_ATTR_NAME).append(',').append(COLUMN_GFF_ATTR_ID).append(
                ")))");
        sql.append(" || ';description=' || apidb.url_escape(trim(COALESCE(").append(
                COLUMN_GFF_ATTR_DESCRIPTION).append(',').append(
                COLUMN_GFF_ATTR_NAME).append(",").append(COLUMN_GFF_ATTR_ID).append(
                ")))");

        sql.append(" || ';size=' || ").append(COLUMN_GFF_ATTR_SIZE);

        if (includeParent) {
            sql.append(" || ';Parent=' || trim(").append(COLUMN_GFF_ATTR_PARENT).append(
                    ")");
        }
    }

    private void getTableNameRowCountSql(StringBuffer sql, String tableName) {
        sql.append("'").append(tableName).append("',1,");
    }

    private void getTableIdModificationDateSql(StringBuffer sql) {
        // use the cache table name to generate the sequence name.
        int idx = cacheTable.indexOf('.');
        String schema = (idx < 0) ? null : cacheTable.substring(0, idx);
        String table = (idx < 0) ? cacheTable : cacheTable.substring(idx + 1);
        sql.append('(').append(
                wdkModel.getUserDb().getPlatform().getNextIdSqlExpression(schema, table));
        sql.append("), sysdate ");
    }

    private void getSelectPkColumns(StringBuffer sql, String prefix) {
        String[] pkColumns = recordClass.getPrimaryKeyAttributeField().getColumnRefs();
        for (String column : pkColumns) {
            if (prefix != null) sql.append(prefix).append('.');
            sql.append(column).append(',');
        }
    }

    private void getJoinPkColumns(StringBuffer sql, String tableName,
            String joinTableName, boolean outerJoin, boolean firstColumn) {
        String[] pkColumns = recordClass.getPrimaryKeyAttributeField().getColumnRefs();
        for (String pkColumn : pkColumns) {
            if (firstColumn) {
                if (outerJoin) {
                    sql.append(" ON ");
                } else {
                    sql.append(" WHERE ");
                }
                firstColumn = false;
            } else {
                sql.append(" AND ");
            }
            sql.append(tableName).append('.').append(pkColumn).append(" = ");
            sql.append(joinTableName).append('.').append(pkColumn);
        }
    }

    private void getGroupPkColumns(StringBuffer sql, String prefix) {
        String[] pkColumns = recordClass.getPrimaryKeyAttributeField().getColumnRefs();

        boolean firstColumn = true;
        for (String pkColumn : pkColumns) {
            if (firstColumn) {
                sql.append(" GROUP BY ");
                firstColumn = false;
            } else {
                sql.append(',');
            }
            if (prefix != null) sql.append(prefix).append('.');
            sql.append(pkColumn);
        }
    }
}
