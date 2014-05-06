/**
 * 
 */
package org.apidb.apicommon.model.maintain.users5;

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

import javax.sql.DataSource;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.UtilityMapper;
import org.gusdb.fgputil.db.SqlUtils;
import org.gusdb.fgputil.db.platform.DBPlatform;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * @author Jerric
 *
 */
public class Users5StepParamsTask implements MigrationTask, ModelAware {

  private static final int PAGE_SIZE = 250;

  private static final Logger LOG = Logger.getLogger(Users5StepParamsTask.class);

  private WdkModel wdkModel;

  /*
   * (non-Javadoc)
   * 
   * @see org.apidb.apicommon.model.maintain.users5.ModelAware#setModel(org.gusdb.wdk.model.WdkModel)
   */
  @Override
  public void setModel(WdkModel wdkModel) {
    this.wdkModel = wdkModel;
  }

  /*
   * (non-Javadoc)
   * 
   * @see org.apidb.apicommon.model.maintain.users5.MigrationTask#getDisplay()
   */
  @Override
  public String getDisplay() {
    return "Fix userlogins5 step params";
  }

  /*
   * (non-Javadoc)
   * 
   * @see org.apidb.apicommon.model.maintain.users5.MigrationTask#isBatchEnabled()
   */
  @Override
  public boolean isBatchEnabled() {
    return false;
  }

  /*
   * (non-Javadoc)
   * 
   * @see
   * org.apidb.apicommon.model.maintain.users5.MigrationTask#execute(org.apache.ibatis.session.SqlSession)
   */
  @Override
  public void execute(SqlSession session) throws Exception {
    LOG.info("Expanding the checksums in the step params...");
    UtilityMapper mapper = session.getMapper(UtilityMapper.class);

    String sqlStep = "SELECT s.step_id, s.display_params FROM userlogins5.steps s, userlogins5.users u "
        + " WHERE s.user_id = u.user_id AND u.is_guest = 0 AND s.display_params LIKE '%\"[C]%'";
    String sqlUpdate = "UPDATE userlogins5.steps SET display_params = ? WHERE step_id = ?";
    ResultSet rsStep = null;
    PreparedStatement psUpdate = null;
    DBPlatform platform = wdkModel.getUserDb().getPlatform();
    DataSource dataSource = wdkModel.getUserDb().getDataSource();
    try {
      rsStep = SqlUtils.executeQuery(dataSource, sqlStep, "migrate5-select-steps", 1000);
      psUpdate = SqlUtils.getPreparedStatement(dataSource, sqlUpdate);
      int count = 0;
      while (rsStep.next()) {
        int stepId = rsStep.getInt("step_id");
        String params = platform.getClobData(rsStep, "display_params");
        JSONObject jsContent = new JSONObject(params);
        JSONObject jsParams;
        if (jsContent.has("params")) {
          jsParams = jsContent.getJSONObject("params");
        }
        else {
          jsParams = jsContent;
          jsContent = new JSONObject();
          jsContent.put("filters", new JSONObject());
        }
        boolean updated = processParamValues(mapper, stepId, jsParams);

        if (updated) {
          // while updating, change to new storage format
          jsContent.put("params", jsParams);
          platform.setClobData(psUpdate, 1, jsContent.toString(), false);
          psUpdate.setInt(2, stepId);
          psUpdate.addBatch();
          count++;
          if (count % PAGE_SIZE == 0) {
            psUpdate.executeBatch();
          }
          if (count % 1000 == 0)
            LOG.debug(count + " steps updated.");
        }
      }
      psUpdate.executeBatch();
      LOG.debug("Totally " + count + " steps updated.");
    }
    catch (SQLException | JSONException ex) {
      throw new WdkModelException(ex);
    }
    finally {
      SqlUtils.closeResultSetAndStatement(rsStep);
      SqlUtils.closeStatement(psUpdate);
    }
  }

  private boolean processParamValues(UtilityMapper mapper, int stepId, JSONObject jsParams)
      throws JSONException {
    boolean updated = false;
    String[] names = JSONObject.getNames(jsParams);
    if (names == null)
      return updated;
    for (String name : names) {
      String value = jsParams.getString(name);
      if (value.startsWith("[C]")) {
        String checksum = value.substring(3);
        value = mapper.selectClobValue(checksum);
        if (value != null) {
          jsParams.put(name, value);
          updated = true;
        }
        else
          LOG.warn("checksum in step #" + stepId + " is invalid: " + checksum);
      }
    }
    return updated;
  }

  @Override
  public boolean validate(SqlSession session) {
    // TODO - need to add validations later
    return true;
  }
}
