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
import org.gusdb.fgputil.db.SqlUtils;
import org.gusdb.fgputil.db.platform.DBPlatform;
import org.gusdb.wdk.model.Utilities;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;

/**
 * @author Jerric
 *
 */
public class Users5DatasetsTask implements MigrationTask, ModelAware {

  private static final int PAGE_SIZE = 250;
  private static final Logger LOG = Logger.getLogger(Users5DatasetsTask.class);

  private WdkModel wdkModel;

  /*
   * (non-Javadoc)
   * 
   * @see org.apidb.apicommon.model.maintain.users5.MigrationTask#getDisplay()
   */
  @Override
  public String getDisplay() {
    return "Fix userlogins5 Datasets";
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

  @Override
  public void setModel(WdkModel wdkModel) {
    this.wdkModel = wdkModel;
  }

  /*
   * (non-Javadoc)
   * 
   * @see
   * org.apidb.apicommon.model.maintain.users5.MigrationTask#execute(org.apache.ibatis.session.SqlSession)
   */
  @Override
  public void execute(SqlSession session) throws Exception {
    LOG.info("Generating the content and checksum for the datasets...");

    String sqlSelect = "SELECT d.dataset_id, dv.data1, dv.data2, dv.data3                        "
        + " FROM userlogins5.datasets d, userlogins5.dataset_values dv "
        + " WHERE d.dataset_id = dv.dataset_id AND d.content IS NULL "
        + " ORDER BY dataset_id ASC, dataset_value_id ASC";
    String sqlUpdate = "UPDATE userlogins5.datasets "
        + "SET content_checksum = ?, content = ? WHERE dataset_id = ?";
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
            if (count % PAGE_SIZE == 0) {
              psUpdate.executeBatch();
            }
            if (count % 1000 == 0)
              LOG.debug(count + " datasets updated.");
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
      LOG.debug("Totally " + count + " datasets updated.");
    }
    catch (SQLException ex) {
      throw new WdkModelException(ex);
    }
    finally {
      SqlUtils.closeResultSetAndStatement(rsSelect, null);
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
    }
    catch (SQLException ex) {
      throw new WdkModelException(ex);
    }
    return true;
  }

  @Override
  public boolean validate(SqlSession session) {
    // TODO - need to add validations later
    return true;
  }
}
