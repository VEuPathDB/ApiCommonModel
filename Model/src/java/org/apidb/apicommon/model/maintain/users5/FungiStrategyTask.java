package org.apidb.apicommon.model.maintain.users5;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.FungiStrategyMapper;

/**
 * @author jerric
 * 
 *         The task migrate user baskets for fungi users. This task has to be executed after FungiUserTask.
 */
public class FungiStrategyTask implements MigrationTask {

  private static final Logger LOG = Logger.getLogger(FungiStrategyTask.class);

  @Override
  public String getDisplay() {
    return "Migrate user strategies";
  }

  @Override
  public boolean isBatchEnabled() {
    return false;
  }

  @Override
  public void execute(SqlSession session) throws Exception {
    FungiStrategyMapper mapper = session.getMapper(FungiStrategyMapper.class);

    // delete guest strategies in userlogins4, that have conflicting ids with the fungi strategies of
    // registered users in userlogins3.
    int count = mapper.deleteGuestStrategies();
    LOG.debug(count + " guest strategies deleted.");

    // delete guest strategies with conflicting root steps, so that those root steps can be deleted.
    count = mapper.deleteGuestStrategiesByRoot();
    LOG.debug(count + " guest strategies with conflicting root steps deleted.");

    // delete old fungi strategies
    count = mapper.deleteGuestStrategiesByRoot();
    LOG.debug(count + " old fungi strategies deleted.");

    // Insert conflicting strategies, and each strategy will get a new strategy_id, with old id stored in
    // prev_strategy_id.
    // this doesn't include the strategies from duplicated users.
    count = mapper.insertConflictStrategies();
    LOG.debug(count + " conflicting steps inserted.");

    // insert fungi strategies with ids unchanged; this doesn't include strategies from duplicated users
    count = mapper.insertNewStrategies();
    LOG.debug(count + " new strategies inserted.");

    // insert conflicting fungi strategies for the duplicated users, and each strategy will get a new
    // strategy_id, with old
    // id stored in prev_strategy_id.
    count = mapper.insertDuplicateUsersConflictStrategies();
    LOG.debug(count + " conflicting strategies for users with changed ids are inserted.");

    // insert new fungi strategies for the duplicated users
    count = mapper.insertDuplicateUsersNewStrategies();
    LOG.debug(count + " new strategies for users with changed ids are inserted.");

    // update root_step_id for the steps with conflicting ids
    count = mapper.updateRootSteps();
    LOG.debug(count + " root step ids updated.");
  }

}
