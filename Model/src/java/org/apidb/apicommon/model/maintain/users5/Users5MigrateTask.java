/**
 * 
 */
package org.apidb.apicommon.model.maintain.users5;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.MigrateUsers5Mapper;

/**
 * @author Jerric
 *
 */
public class Users5MigrateTask implements MigrationTask {

  private static final Logger LOG = Logger.getLogger(Users5MigrateTask.class);

  /*
   * (non-Javadoc)
   * 
   * @see org.apidb.apicommon.model.maintain.users5.MigrationTask#getDisplay()
   */
  @Override
  public String getDisplay() {
    return "Migrate user data to userlogins5";
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
    MigrateUsers5Mapper mapper = session.getMapper(MigrateUsers5Mapper.class);

    LOG.info("Migrating users from userlogins4 to userlogins5...");

    int count = mapper.insertUsers();
    LOG.debug(count + " users migrated.");

    count = mapper.insertUserRoles();
    LOG.debug(count + " user roles migrated.");

    count = mapper.insertPreferences();
    LOG.debug(count + " preferences migrated.");

    count = mapper.insertBaskets();
    LOG.debug(count + " user baskets migrated.");

    count = mapper.insertFavorite();
    LOG.debug(count + " user favorites migrated.");

    count = mapper.insertSteps();
    LOG.debug(count + " steps migrated.");

    count = mapper.insertStrategies();
    LOG.debug(count + " strategies migrated.");

    while (true) {
      count = mapper.deleteUnusedSteps();
      if (count == 0)
        break;
      LOG.debug(count + " unused steps deleted.");
    }

    count = mapper.insertDatasets();
    LOG.debug(count + " datasets migrated.");

    count = mapper.insertDatasetValues();
    LOG.debug(count + " dataset values migrated.");
  }

  @Override
  public boolean validate(SqlSession session) {
    // TODO - need to add validations later
    return true;
  }

}
