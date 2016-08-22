package org.apidb.apicommon.model.maintain.users5;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.FungiBasketMapper;

/**
 * @author jerric
 * 
 *         The task migrate user baskets for fungi users. This task has to be executed after
 *         FungiUserTask.
 */
public class FungiBasketTask implements MigrationTask {

  private static final Logger LOG = Logger.getLogger(FungiBasketTask.class);

  @Override
  public String getDisplay() {
    return "Migrate user baskets";
  }

  @Override
  public boolean isBatchEnabled() {
    return false;
  }

  @Override
  public void execute(SqlSession session) throws Exception {
    FungiBasketMapper mapper = session.getMapper(FungiBasketMapper.class);

    // delete all fungi related baskets from userlogins4, since userlogins3 might have newer data.
    int count = mapper.deleteBaskets();
    LOG.debug(count + " old fungi baskets deleted.");

    // insert back fungi baskets for existing users, excluding users with changed ids
    count = mapper.insertExistingBaskets();
    LOG.debug(count + " fungi baskets inserted.");

    // insert fungi baskets for users with changed ids.
    count = mapper.insertDuplicateBaskets();
    LOG.debug(count + " baskets for users with changed ids are inserted.");
  }

  @Override
  public boolean validate(SqlSession session) {
    // TODO - need to add validations later
    return true;
  }

}
