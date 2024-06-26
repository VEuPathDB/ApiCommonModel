/**
 * 
 */
package org.apidb.apicommon.model.maintain;

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

import javax.sql.DataSource;

import org.apache.log4j.Logger;
import org.gusdb.fgputil.BaseCLI;
import org.gusdb.fgputil.db.SqlUtils;
import org.gusdb.wdk.model.Utilities;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;

/**
 * @author xingao
 * 
 *         The code load model info into local tables, and will be used to
 *         validate steps.
 */
public class BasketFixer extends BaseCLI {

  private static final Logger logger = Logger.getLogger(BasketFixer.class);

  // account used to run maintennace scripts
  private static final String WDKMAINT = "wdkmaint.";

  public static void main(String[] args) {
    String cmdName = System.getProperty("cmdName");
    BasketFixer cacher = new BasketFixer(cmdName);
    try {
      cacher.invoke(args);
    } catch (Exception ex) {
      ex.printStackTrace();
      System.exit(1);
    } finally {
      logger.info("basket fixer done.");
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
   * @see org.gusdb.fgputil.BaseCLI#declareOptions()
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
   * @see org.gusdb.fgputil.BaseCLI#execute()
   */
  @Override
    protected void execute() throws Exception {
    String gusHome = System.getProperty(Utilities.SYSTEM_PROPERTY_GUS_HOME);

    String strProject = (String) getOptionValue(ARG_PROJECT_ID);
    String[] projects = strProject.split(",");

    for (String projectId : projects) {
      logger.info("Fixing basket for project " + projectId);
      try (WdkModel wdkModel = WdkModel.construct(projectId, gusHome)) {
        fixBasket(wdkModel, "TranscriptRecordClasses.TranscriptRecordClass", "ApidbTuning.GeneId",  "gene");
        updateTranscripts(wdkModel, projectId);
        fixBasket(wdkModel, "SequenceRecordClasses.SequenceRecordClass", "ApidbTuning.GenomicSequenceId",  "sequence");
        logger.info("=========================== done ============================");
      }
    }
  }

  public void fixBasket(WdkModel wdkModel, String type, String aliasTable, String idColumn) throws WdkModelException {
    logger.info("Fixing "+type+" basket...");

    Map<Integer, Map<String, String>> users = getDeprecatedIds(wdkModel,
                                                               type, aliasTable, idColumn);
    for (int userId : users.keySet()) {
      Map<String, String> ids = users.get(userId);
      changeIds(wdkModel, type, userId, ids);
    }
  }

  private Map<Integer, Map<String, String>> getDeprecatedIds(
                                                             WdkModel wdkModel, String type, String aliasTable, String idColumn)
    throws WdkModelException {
    Map<Integer, Map<String, String>> users = new HashMap<Integer, Map<String, String>>();

    String userSchema = wdkModel.getModelConfig().getUserDB().getUserSchema();
    String dblink = wdkModel.getModelConfig().getAppDB().getUserDbLink();
    DataSource dataSource = wdkModel.getAppDb().getDataSource();
    String sql = "SELECT b.user_id, b.pk_column_1 AS old_id,        "
      + "          a." + idColumn + " AS new_id               "
      + "   FROM " + userSchema + "user_baskets" + dblink + " b "
      + "     LEFT JOIN " + aliasTable + " a "
      + "       ON b.pk_column_1 = a.id "
      + "   WHERE b.project_id = ? AND b.record_class = ?";

    ResultSet resultSet = null;
    PreparedStatement ps = null;
    try {
      logger.debug("executing sql to find invalid basket ids...\n" + sql);
      ps = SqlUtils.getPreparedStatement(dataSource,
                                                           sql);
      ps.setFetchSize(5000);
      ps.setString(1, wdkModel.getProjectId());
      ps.setString(2, type);
      resultSet = ps.executeQuery();
      logger.debug("sql returned.");
      while (resultSet.next()) {
        int userId = resultSet.getInt("user_id");
        String oldId = resultSet.getString("old_id");
        String newId = resultSet.getString("new_id");

        Map<String, String> ids = users.get(userId);
        if (ids == null) {
          ids = new HashMap<String, String>();
          users.put(userId, ids);
        }
        ids.put(oldId, newId);
      }

      Integer[] userIds = new Integer[users.size()];
      users.keySet().toArray(userIds);
      for (Integer userId : userIds) {
        Map<String, String> ids = users.get(userId);
        // if the old id maps to a new id, but the new id is also in the
        // basket, then need to remove the old id, by setting the new id
        // to null.
        String[] oldIds = new String[ids.size()];
        ids.keySet().toArray(oldIds);
        for (String oldId : oldIds) {
          String newId = ids.get(oldId);
          // if new id is null, meaning old id to be removed, don't
          // process here.
          if (newId == null) continue;

          // if old id == new id, don't process here. this entry will
          // be discarded later.
          if (oldId.equals(newId)) continue;

          if (ids.containsKey(newId)) {
            // new id already exist, remove the old id by setting
            // new id to null.
            ids.put(oldId, null);
          } else {
            // new id doesn't exist, add new id into the list, so
            // that other old id which maps to this new id will be
            // removed. However, the current old id will be mapped.
            ids.put(newId, newId);
          }
        }

        // discard entries where old id == new id; this has to be done
        // after the previous step.
        oldIds = new String[ids.size()];
        ids.keySet().toArray(oldIds);
        for (String oldId : oldIds) {
          String newId = ids.get(oldId);
          if (newId != null && oldId.equals(newId))
            ids.remove(oldId);
        }

        // if the user has no id to process, discard the user
        if (ids.size() == 0) users.remove(userId);
      }
      logger.info("total " + users.size()
                  + " users needs to be changed, based on " + aliasTable);
    }
    catch (SQLException e) {
      throw new WdkModelException(e);
    }
    finally {
      SqlUtils.closeResultSetAndStatement(resultSet, ps);
    }
    return users;
  }

  private void changeIds(WdkModel wdkModel, String type, int userId,
                         Map<String, String> ids) throws WdkModelException {
    logger.info("Updating basket for user #" + userId);
        
    String userSchema = wdkModel.getModelConfig().getUserDB().getUserSchema();
    DataSource dataSource = wdkModel.getUserDb().getDataSource();
    String sqlUpdate = "UPDATE " + userSchema + "user_baskets "
      + " SET pk_column_1 = ? "
      + " WHERE project_id = ? AND user_id = ? "
      + "   AND record_class = ? AND pk_column_1 = ?";
    String sqlDelete = "DELETE FROM " + userSchema + "user_baskets "
      + " WHERE project_id = ? AND user_id = ? "
      + "   AND record_class = ? AND pk_column_1 = ?";

    PreparedStatement psUpdate = null, psDelete = null;
    try {
      psUpdate = SqlUtils.getPreparedStatement(dataSource,
                                               sqlUpdate.toString());
      psDelete = SqlUtils.getPreparedStatement(dataSource,
                                               sqlDelete.toString());

      int count = 0;  // <ADD-AG 050111>

      for (String oldId : ids.keySet()) {
        String newId = ids.get(oldId);
        if (newId == null) {
          logger.trace("deleting user #" + userId + " basket id: "
                       + oldId + " of type " + type);
          psDelete.setString(1, wdkModel.getProjectId());
          psDelete.setInt(2, userId);
          psDelete.setString(3, type);
          psDelete.setString(4, oldId);
          psDelete.addBatch();
        } else {
          logger.trace("change user #" + userId + " basket id: "
                       + oldId + " to " + newId + " of type " + type);
          psUpdate.setString(1, newId);
          psUpdate.setString(2, wdkModel.getProjectId());
          psUpdate.setInt(3, userId);
          psUpdate.setString(4, type);
          psUpdate.setString(5, oldId);
          psUpdate.addBatch();
        }

        // <ADD-AG 050111> ------------------------------------------------------
        count++;
        if (count % 500 == 0) {
          psUpdate.executeBatch();
          psDelete.executeBatch();
          logger.info("Rows processed by changeIds = " + count + ".");
        }
        // </ADD-AG 050111> -----------------------------------------------------

      }
      psUpdate.executeBatch();
      psDelete.executeBatch();

      logger.info("Total rows processed by changeIds = " + count + ".");  // <ADD-AG 050111>
    }
    catch (SQLException e) {
      throw new WdkModelException(e);
    }
    finally {
      SqlUtils.closeStatement(psUpdate);
      SqlUtils.closeStatement(psDelete);
    }
  }
    
  private void updateTranscripts(WdkModel wdkModel, String projectId) throws WdkModelException {
      
    logger.info("Updating transcripts...");
    String userSchema = wdkModel.getModelConfig().getUserDB().getUserSchema();
    DataSource userDbDataSource = wdkModel.getUserDb().getDataSource();
    DataSource appDbDataSource = wdkModel.getAppDb().getDataSource();
    String dblink = wdkModel.getModelConfig().getAppDB().getUserDbLink();
    
    long timestamp = new Date().getTime() / 10000;
    String tmpTable = "bt_" + projectId + "_" + timestamp; // give each table a unique name, so we can restore from it, if insert fails.
      
    String allTranscriptRowsSql = " from " + userSchema + "user_baskets"
      + " WHERE project_id = '" + wdkModel.getProjectId() + "'"
      + " AND record_class = 'TranscriptRecordClasses.TranscriptRecordClass'";

    String createTempTableSql = "CREATE TABLE " + tmpTable + " AS (select * " + allTranscriptRowsSql + ")";
    String deleteBasketTranscriptsSql = "DELETE " + allTranscriptRowsSql;
      
    // this SQL requires that an appDB is able to access a table with owner wdkmaint (account to access the user database) via dblink
    // apicommdev dblink allows that access from our appDBs, make sure the dblink to your test database includes this permission 
    String insertTranscriptsSql = 
        "INSERT into " +  userSchema + "user_baskets" + dblink 
      + "  (BASKET_ID, USER_ID, BASKET_NAME, PROJECT_ID, RECORD_CLASS, IS_DEFAULT, CATEGORY_ID, PK_COLUMN_1, PK_COLUMN_3, PREV_BASKET_ID, MIGRATION_ID, PK_COLUMN_2)"
      + " SELECT "
      +      userSchema + "user_baskets_pkseq.nextval" + dblink + ", b.*, t.source_id as pk_column_2"
      + " FROM "
      + "   (SELECT USER_ID, BASKET_NAME, PROJECT_ID, RECORD_CLASS, IS_DEFAULT, CATEGORY_ID,  tmp.PK_COLUMN_1, PK_COLUMN_3, PREV_BASKET_ID, MIGRATION_ID"
      + "    FROM "
      + "     (SELECT pk_column_1, MAX(pk_column_2) AS pk_column_2"
      + "       FROM " + WDKMAINT + tmpTable + dblink
      + "       GROUP BY pk_column_1) geneAndMaxTrans,"
      + "    " + WDKMAINT + tmpTable + dblink + " tmp"
      + "     WHERE geneAndMaxTrans.pk_column_1 = tmp.pk_column_1"
      + "       AND geneAndMaxTrans.pk_column_2 = tmp.pk_column_2"
      + "   ) b," // one row per gene, all basket columns, but excludes pk_column_2, ie, the trans id
      + "   apiDBTuning.TranscriptAttributes t"
      + " WHERE b.pk_column_1 = t.gene_source_id";


    try {
      if (wdkModel.getUserDb().getPlatform().checkTableExists(userDbDataSource, wdkModel.getUserDb().getDefaultSchema(), tmpTable))
        SqlUtils.executeUpdate(userDbDataSource, "DROP TABLE " + tmpTable, "basket-maintenance-delete-temp-table");
         
      // copy transcript baskets to temp table
      SqlUtils.executeUpdate(userDbDataSource, createTempTableSql, "basket-maintenance-create-temp-table");
        
      // delete transcript baskets from basket table
      SqlUtils.executeUpdate(userDbDataSource, deleteBasketTranscriptsSql, "basket-maintenance-delete-transcripts");

      // join to appDb to insert new set of transcripts for each gene into basket
      SqlUtils.executeUpdate(appDbDataSource, insertTranscriptsSql, "basket-maintenance-insert-transcripts");
      
      // delete temp table
      //SqlUtils.executeUpdate(userDbDataSource, "DROP TABLE basketTemp", "basket-maintenance-delete-temp-table");
    }
    catch (SQLException e) {
      throw new WdkModelException(e);
    }
         
  }
}
