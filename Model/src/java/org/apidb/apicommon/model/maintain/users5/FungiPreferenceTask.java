package org.apidb.apicommon.model.maintain.users5;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.FungiPreferenceMapper;

/**
 * @author jerric
 * 
 *         The task migrate user preferences for fungi users. This task has to be executed after
 *         FungiUserTask.
 */
public class FungiPreferenceTask implements MigrationTask {

  private static final Logger LOG = Logger.getLogger(FungiPreferenceTask.class);

  @Override
  public String getDisplay() {
    return "Migrate user preference";
  }

  @Override
  public boolean isBatchEnabled() {
    return false;
  }

  @Override
  public void execute(SqlSession session) throws Exception {
    FungiPreferenceMapper mapper = session.getMapper(FungiPreferenceMapper.class);

    // delete all fungi related user preferences from userlogins4, since userlogins3 might have newer data.
    int count = mapper.deletePreferences();
    LOG.debug(count + " old fungi preferences deleted.");

    // insert back fungi preferences for existing users, excluding users with changed ids
    count = mapper.insertExistingPreferences();
    LOG.debug(count + " fungi preferences inserted.");

    // insert all preferences for new users, excluding fungi preferences, which were inserted in the previous
    // step
    count = mapper.insertNewPreferences();
    LOG.debug(count + " new preferences inserted.");

    // insert fungi preferences for users with changed ids.
    count = mapper.insertDuplicatePreferences();
    LOG.debug(count + " preferences for users with changed ids are inserted.");
  }

  @Override
  public boolean validate(SqlSession session) {
    // TODO - need to add validations later
    return true;
  }

}
