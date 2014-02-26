package org.apidb.apicommon.model.maintain;

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

import javax.sql.DataSource;

import org.apache.log4j.Logger;
import org.gusdb.fgputil.db.SqlUtils;
import org.gusdb.fgputil.db.platform.DBPlatform;
import org.gusdb.wdk.model.Utilities;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wsf.util.BaseCLI;
import org.json.JSONException;
import org.json.JSONObject;

public class UserMigration5 extends BaseCLI {

  private static final Logger logger = Logger.getLogger(UserMigration5.class);

  public static void main(String[] args) throws Exception {
    String cmdName = System.getProperty("cmdName");
    UserMigration5 cacher = new UserMigration5(cmdName);
    try {
      cacher.invoke(args);
    }
    catch (Exception ex) {
      ex.printStackTrace();
      throw ex;
    }
    finally {
      logger.info("user migration 5 is done.");
      System.exit(0);
    }
  }

  protected UserMigration5(String command) {
    super((command != null) ? command : "wdkUserMigration5", "Fix user data in the new userlogins5 schema.");
  }

  @Override
  protected void declareOptions() {
    addSingleValueOption(ARG_PROJECT_ID, true, null, "any project_id. Only one project is needed to provide "
        + "connection information to the apicomm, and the data for all the projects will be fixed in the "
        + "userlogins5 schema.");
  }

  @Override
  protected void execute() throws Exception {
    String gusHome = System.getProperty(Utilities.SYSTEM_PROPERTY_GUS_HOME);
    String projectId = (String) getOptionValue(ARG_PROJECT_ID);
    logger.info("Fixing user data in new user login schema...");
    WdkModel wdkModel = WdkModel.construct(projectId, gusHome);

    String schema = wdkModel.getModelConfig().getUserDB().getUserSchema();
    logger.info("User schema: " + schema);

    logger.info("Fixing datasets...");
    fixDatasets(wdkModel, schema);
    logger.info("Fixing steps...");
    fixSteps(wdkModel, schema);
  }

  private void fixDatasets(WdkModel wdkModel, String schema) throws WdkModelException {
    String sqlSelect = "SELECT dataset_id, data1, data2, data3 FROM " + schema + "dataset_values " +
        " ORDER BY dataset_id ASC, dataset_value_id ASC";
    String sqlUpdate = "UPDATE " + schema + "datasets " +
        "SET content_checksum = ?, content = ? WHERE dataset_id = ?";
    ResultSet rsSelect = null;
    PreparedStatement psUpdate = null;
    DBPlatform platform = wdkModel.getUserDb().getPlatform();
    DataSource dataSource = wdkModel.getUserDb().getDataSource();
    try {
      rsSelect = SqlUtils.executeQuery(dataSource, sqlSelect, "migrate5-select-dataset-values", 5000);
      psUpdate = SqlUtils.getPreparedStatement(dataSource, sqlUpdate);
      StringBuilder content = new StringBuilder();
      int prevDatasetId = 0;
      int count = 0;
      while (rsSelect.next()) {
        int datasetId = rsSelect.getInt("dataset_id");
        if (datasetId != prevDatasetId) { // reach a new dataset, process the previous one first.
          if (updateDataset(platform, psUpdate, prevDatasetId, content.toString())) {
            count++;
            if (count % 100 == 0) {
              psUpdate.executeBatch();
              logger.info(count + " datasets updated.");
            }
          }
          prevDatasetId = datasetId;
          content = new StringBuilder();
        }
        content.append(rsSelect.getString("data1"));
        String data2 = rsSelect.getString("data2");
        if (data2 != null)
          content.append(",").append(data2);
        String data3 = rsSelect.getString("data3");
        if (data3 != null)
          content.append(",").append(data3);
        content.append("\n");
      }
      // process the last dataset
      updateDataset(platform, psUpdate, prevDatasetId, content.toString());
      psUpdate.executeBatch();
      logger.info("Totally " + count + " datasets updated.");
    }
    catch (SQLException ex) {
      throw new WdkModelException(ex);
    }
    finally {
      SqlUtils.closeResultSetAndStatement(rsSelect);
      SqlUtils.closeStatement(psUpdate);
    }
  }

  private boolean updateDataset(DBPlatform platform, PreparedStatement psUpdate, int datasetId, String content)
      throws WdkModelException {
    if (content.length() == 0)
      return false;

    // generate content checksum
    String checksum = Utilities.encrypt(content);

    try {
      psUpdate.setString(1, checksum);
      platform.setClobData(psUpdate, 2, content, false);
      psUpdate.setInt(3, datasetId);
      psUpdate.addBatch();
      ;
    }
    catch (SQLException ex) {
      throw new WdkModelException(ex);
    }
    return true;
  }

  private void fixSteps(WdkModel wdkModel, String schema) throws WdkModelException {
    String sqlStep = "SELECT step_id, display_params FROM " + schema + "steps";
    String sqlClob = "SELECT clob_value FROM wdkengine.clob_values WHERE clob_checksum = ?";
    String sqlUpdate = "UPDATE " + schema + "steps SET display_params = ? WHERE step_id = ?";
    ResultSet rsStep = null;
    PreparedStatement psClob = null, psUpdate = null;
    DBPlatform platform = wdkModel.getUserDb().getPlatform();
    DataSource dataSource = wdkModel.getUserDb().getDataSource();
    try {
      rsStep = SqlUtils.executeQuery(dataSource, sqlStep, "migrate5-select-steps", 1000);
      psClob = SqlUtils.getPreparedStatement(dataSource, sqlClob);
      psUpdate = SqlUtils.getPreparedStatement(dataSource, sqlUpdate);
      int count = 0, stepCount = 0;
      while (rsStep.next()) {
        stepCount++;
        int stepId = rsStep.getInt("step_id");
        String params = platform.getClobData(rsStep, "display_params");
        JSONObject jsParams = new JSONObject(params);
        boolean updated = processParamValues(platform, psClob, stepId, jsParams);
        if (updated) {
          platform.setClobData(psUpdate, 1, jsParams.toString(), false);
          psUpdate.setInt(2, stepId);
          psUpdate.addBatch();
          count++;
          if (count % 100 == 0) {
            psUpdate.executeBatch();
            logger.info(count + " steps updated, " + stepCount + " steps processed.");
          }
        }
      }
      if (count % 100 != 0) {
        psUpdate.executeBatch();
        logger.info("Totally " + count + " steps updated, " + stepCount + " steps processed.");
      }
    }
    catch (SQLException | JSONException ex) {
      throw new WdkModelException(ex);
    }
    finally {
      SqlUtils.closeResultSetAndStatement(rsStep);
      SqlUtils.closeStatement(psClob);
      SqlUtils.closeStatement(psUpdate);
    }
  }

  private boolean processParamValues(DBPlatform platform, PreparedStatement psClob, int stepId,
      JSONObject jsParams) throws SQLException, JSONException {
    boolean updated = false;
    String[] names = JSONObject.getNames(jsParams);
    if (names == null)
      return updated;
    for (String name : names) {
      String value = jsParams.getString(name);
      if (value.startsWith("[C]")) {
        String checksum = value.substring(3);
        ResultSet resultSet = null;
        try {
          psClob.setString(1, checksum);
          resultSet = psClob.executeQuery();
          if (resultSet.next()) {
            value = platform.getClobData(resultSet, "clob_value");
            jsParams.put(name, value);
            updated = true;
          }
          else
            logger.error("checksum in step #" + stepId + " is invalid: " + checksum);
        }
        finally {
          SqlUtils.closeResultSetOnly(resultSet);
        }
      }
    }
    return updated;
  }
}
