package org.apidb.apicommon.model.maintain.users5;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.FungiStepMapper;
import org.apidb.apicommon.model.maintain.users5.mapper.FungiStrategyMapper;

/**
 * @author jerric
 * 
 *         The task migrate user baskets for fungi users. This task has to be executed after FungiUserTask.
 */
public class FungiStepTask implements MigrationTask {

  private static final Logger LOG = Logger.getLogger(FungiStepTask.class);

  @Override
  public String getDisplay() {
    return "Migrate user steps";
  }

  @Override
  public boolean isBatchEnabled() {
    return false;
  }

  @Override
  public void execute(SqlSession session) throws Exception {
    FungiStrategyMapper strategyMapper = session.getMapper(FungiStrategyMapper.class);
    FungiStepMapper mapper = session.getMapper(FungiStepMapper.class);

    // first need to delete guest strategies that uses conflicting root steps
    int count = strategyMapper.deleteGuestStrategiesByRoot();
    LOG.debug(count + " guest strategies deleted.");
    
    // then will also need to delete old strategies, so that the old steps can be deleted
    strategyMapper.deleteOldStrategies();
    LOG.debug(count + " old strategies deleted.");

    // delete userlogins4 guest steps that is in conflict with fungi steps of registered users.
    count = mapper.deleteGuestSteps();
    LOG.debug(count + " guest steps deleted.");

    // delete old fungi steps
    count = mapper.deleteOldSteps();
    LOG.debug(count + " old fungi steps deleted.");

    // Insert conflicting steps, and each step will get a new step_id, with old id stored in prev_step_id.
    // this doesn't include the steps from duplicated users.
    count = mapper.insertConflictSteps();
    LOG.debug(count + " conflicting steps inserted.");

    // insert fungi steps with ids unchanged; this doesn't include steps from duplicated users
    count = mapper.insertNewSteps();
    LOG.debug(count + " new steps inserted.");

    // insert conflicting fungi steps for the duplicated users, and each step will get a new step_id, with old
    // id stored in prev_step_id.
    count = mapper.insertDuplicateUsersConflictSteps();
    LOG.debug(count + " conflicting steps for users with changed ids are inserted.");

    // insert new fungi steps for the duplicated users
    count = mapper.insertDuplicateUsersNewSteps();
    LOG.debug(count + " new steps for users with changed ids are inserted.");

    // update left child ids for the child steps with conflicting ids
    count = mapper.updateLeftSteps();
    LOG.debug(count + " left child steps updated.");

    // update right child ids for the child steps with conflicting ids
    count = mapper.updateRightSteps();
    LOG.debug(count + " right child steps updated.");
  }
}
