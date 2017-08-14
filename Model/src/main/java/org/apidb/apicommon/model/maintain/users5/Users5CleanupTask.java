/**
 * 
 */
package org.apidb.apicommon.model.maintain.users5;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.DeleteUsers5Mapper;

/**
 * @author Jerric
 *
 */
public class Users5CleanupTask implements MigrationTask {

  private static final Logger LOG = Logger.getLogger(Users5CleanupTask.class);

  /* (non-Javadoc)
   * @see org.apidb.apicommon.model.maintain.users5.MigrationTask#getDisplay()
   */
  @Override
  public String getDisplay() {
    return "Clean up user data from userlogins5";
  }

  /* (non-Javadoc)
   * @see org.apidb.apicommon.model.maintain.users5.MigrationTask#isBatchEnabled()
   */
  @Override
  public boolean isBatchEnabled() {
    return false;
  }

  /* (non-Javadoc)
   * @see org.apidb.apicommon.model.maintain.users5.MigrationTask#execute(org.apache.ibatis.session.SqlSession)
   */
  @Override
  public void execute(SqlSession session) throws Exception {
    DeleteUsers5Mapper mapper = session.getMapper(DeleteUsers5Mapper.class);

    LOG.info("Removing all user data from userlogins5...");
    int count = mapper.deletefavorites();
    LOG.debug(count + " favorites deleted.");

    count = mapper.deleteBaskets();
    LOG.debug(count + " baskets deleted.");

    count = mapper.deleteStrategies();
    LOG.debug(count + " strategies deleted.");
    
    count = mapper.deleteSteps();
    LOG.debug(count + " steps deleted.");

    count = mapper.deleteDatasetValues();
    LOG.debug(count + " dataset values deleted.");

    count = mapper.deleteDatasets();
    LOG.debug(count + " datasets deleted.");

    count = mapper.deletePreferences();
    LOG.debug(count + " preferences deleted.");

    count = mapper.deleteUserRoles();
    LOG.debug(count + " user roles deleted.");

    count = mapper.deleteUsers();
    LOG.debug(count + " users deleted.");
  }

  @Override
  public boolean validate(SqlSession session) {
    // TODO - need to add validations later
    return true;
  }

}
