/**
 * 
 */
package org.apidb.apicommon.model.maintain;

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;

import javax.sql.DataSource;

import org.apache.log4j.Logger;
import org.gusdb.wdk.model.Utilities;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.dbms.SqlUtils;
import org.gusdb.wsf.util.BaseCLI;

/**
 * @author xingao
 * 
 *         The code load model info into local tables, and will be used to
 *         validate steps.
 */
public class BasketFixer extends BaseCLI {

    private static final Logger logger = Logger.getLogger(BasketFixer.class);

    /**
     * @param args
     * @throws Exception
     */
    public static void main(String[] args) throws Exception {
        String cmdName = System.getProperty("cmdName");
        BasketFixer cacher = new BasketFixer(cmdName);
        try {
            cacher.invoke(args);
        } catch (Exception ex) {
            ex.printStackTrace();
            throw ex;
        } finally {
            logger.info("model cacher done.");
            System.exit(0);
        }
    }

    /**
     * @param command
     * @param description
     */
    public BasketFixer(String command) {
        super((command != null) ? command : "wdkBasketFixer", "Update the "
                + "record ids in the basket. If the id has been changed, the "
                + "new id will be put into basket; if the record has been "
                + "removed from the database, the id will be removed from "
                + "basket.");
    }

    /*
     * (non-Javadoc)
     * 
     * @see org.gusdb.wsf.util.BaseCLI#declareOptions()
     */
    @Override
    protected void declareOptions() {
        addSingleValueOption(ARG_PROJECT_ID, true, null, "A comma-separated"
                + " list of ProjectIds, which should match the directory name"
                + " under $GUS_HOME, where model-config.xml is stored.");
    }

    /*
     * (non-Javadoc)
     * 
     * @see org.gusdb.wsf.util.BaseCLI#execute()
     */
    @Override
    protected void execute() throws Exception {
        String gusHome = System.getProperty(Utilities.SYSTEM_PROPERTY_GUS_HOME);

        String strProject = (String) getOptionValue(ARG_PROJECT_ID);
        String[] projects = strProject.split(",");

        for (String projectId : projects) {
            logger.info("Fixing basket for project " + projectId);
            WdkModel wdkModel = WdkModel.construct(projectId, gusHome);
            fixGeneBasket(wdkModel);
            logger.info("=========================== done ============================");
        }
    }

    public void fixGeneBasket(WdkModel wdkModel) throws SQLException {
        logger.info("Fixing gene basket...");

        String type = "GeneRecordClasses.GeneRecordClass";
        String aliasTable = "apidb.GeneId";
        String idColumn = "gene";
        Map<String, String> ids = getDeprecatedIds(wdkModel, type, aliasTable,
                idColumn);
        changeIds(wdkModel, type, ids);
    }

    private Map<String, String> getDeprecatedIds(WdkModel wdkModel,
            String type, String aliasTable, String idColumn)
            throws SQLException {
        Map<String, String> ids = new HashMap<String, String>();

        String userSchema = wdkModel.getModelConfig().getUserDB().getUserSchema();
        String dblink = wdkModel.getModelConfig().getAppDB().getUserDbLink();
        DataSource dataSource = wdkModel.getQueryPlatform().getDataSource();
        String sql = "SELECT b.pk_column_1 AS old_id,                   "
                + "          a." + idColumn + " AS new_id               "
                + "   FROM " + userSchema + "user_baskets" + dblink + " b "
                + "     LEFT JOIN " + aliasTable + " a "
                + "       ON b.pk_column_1 = a.alias "
                + "   WHERE b.project_id = ? AND b.record_class = ?";

        ResultSet resultSet = null;
        try {
            logger.debug("executing sql to find invalid basket ids...");
            PreparedStatement ps = SqlUtils.getPreparedStatement(dataSource,
                    sql);
            ps.setString(1, wdkModel.getProjectId());
            ps.setString(2, type);
            resultSet = ps.executeQuery();
            logger.debug("sql returned.");
            while (resultSet.next()) {
                String oldId = resultSet.getString("old_id");
                String newId = resultSet.getString("new_id");
                ids.put(oldId, newId);
            }
        } finally {
            SqlUtils.closeResultSet(resultSet);
        }
        return ids;
    }

    private void changeIds(WdkModel wdkModel, String type,
            Map<String, String> ids) throws SQLException {
        String userSchema = wdkModel.getModelConfig().getUserDB().getUserSchema();
        DataSource dataSource = wdkModel.getUserPlatform().getDataSource();
        String sqlUpdate = "UPDATE " + userSchema + "user_baskets "
                + " SET pk_column_1 = ? "
                + " WHERE project_id = ? AND record_class = ? "
                + "       AND pk_column_1 = ?";
        String sqlDelete = "DELETE FROM " + userSchema + "user_baskets "
                + " WHERE project_id = ? AND record_class = ? "
                + "       AND pk_column_1 = ?";

        PreparedStatement psUpdate = null, psDelete = null;
        try {
            psUpdate = SqlUtils.getPreparedStatement(dataSource,
                    sqlUpdate.toString());
            psDelete = SqlUtils.getPreparedStatement(dataSource,
                    sqlDelete.toString());

            for (String oldId : ids.keySet()) {
                String newId = ids.get(oldId);
                if (newId == null) {
                    logger.debug("deleting basket id: " + oldId + " of type "
                            + type);
                    psDelete.setString(1, wdkModel.getProjectId());
                    psDelete.setString(2, type);
                    psDelete.setString(3, oldId);
                    psDelete.addBatch();
                } else {
                    logger.debug("change basket id: " + oldId + " to " + newId
                            + " of type " + type);
                    psUpdate.setString(1, newId);
                    psUpdate.setString(2, wdkModel.getProjectId());
                    psUpdate.setString(3, type);
                    psUpdate.setString(4, oldId);
                    psUpdate.addBatch();
                }
            }
            // psUpdate.executeBatch();
            // psDelete.executeBatch();
        } finally {
            SqlUtils.closeStatement(psUpdate);
            SqlUtils.closeStatement(psDelete);
        }
    }
}
