package org.apidb.apicommon.model.maintain.users5;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.FungiUserMapper;

public class FungiUserTask implements MigrationTask {

  private static final Logger LOG = Logger.getLogger(FungiUserTask.class);

  @Override
  public String getDisplay() {
    return "Migrate users";
  }

  @Override
  public boolean isBatchEnabled() {
    return false;
  }

  @Override
  public void execute(SqlSession session) throws Exception {
    FungiUserMapper mapper = session.getMapper(FungiUserMapper.class);

    LOG.info("Migrating users from userlogins3 to userlogins4...");

    // find new users which exists only in userlogins3, and both user_id and email don't exist in userlogins4.
    TaskUtility.prepareTempUsersTable(session);
    int count = mapper.findNewUsers();
    LOG.debug(count + " new users found in userlogins3.");

    // find duplicated users which has same email in both userlogins3 & 4, but different user_ids
    TaskUtility.prepareUserMapTable(session);
    count = mapper.findDuplicateUsers();
    LOG.debug(count + " duplicated users found in userlogins3.");

    // inserting new users into userlogins4
    count = mapper.insertNewUsers();
    LOG.debug(count + " new users inserted into userlogins4.");
    
    // copy over the user roles for the new users
    count = mapper.insertNewRoles();
    LOG.debug(count + " user roles inserted into userlogins4.");
  }
}
