package org.apidb.apicommon.model.maintain.users5;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.FungiFavoriteMapper;

/**
 * @author jerric
 * 
 *         The task migrate user favorites for fungi users. This task has to be executed after
 *         FungiUserTask.
 */
public class FungiFavoriteTask implements MigrationTask {

  private static final Logger LOG = Logger.getLogger(FungiFavoriteTask.class);

  @Override
  public String getDisplay() {
    return "Migrate favorites";
  }

  @Override
  public boolean isBatchEnabled() {
    return false;
  }

  @Override
  public void execute(SqlSession session) throws Exception {
    FungiFavoriteMapper mapper = session.getMapper(FungiFavoriteMapper.class);

    // delete all fungi related favorites from userlogins4, since userlogins3 might have newer data.
    int count = mapper.deleteFavorites();
    LOG.debug(count + " old fungi favorites deleted.");

    // insert back fungi favorite for existing users, excluding users with changed ids
    count = mapper.insertExistingFavorites();
    LOG.debug(count + " fungi favorites inserted.");

    // insert fungi favorites for users with changed ids.
    count = mapper.insertDuplicateFavorites();
    LOG.debug(count + " favorites for users with changed ids are inserted.");
  }

  @Override
  public boolean validate(SqlSession session) {
    // TODO - need to add validations later
    return true;
  }

}
