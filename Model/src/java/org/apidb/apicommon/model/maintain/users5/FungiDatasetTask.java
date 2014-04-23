package org.apidb.apicommon.model.maintain.users5;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.FungiDatasetMapper;

/**
 * @author jerric
 * 
 *         The task migrate user baskets for fungi users. This task has to be executed after
 *         FungiUserTask.
 */
public class FungiDatasetTask implements MigrationTask {

  private static final Logger LOG = Logger.getLogger(FungiDatasetTask.class);

  @Override
  public String getDisplay() {
    return "Migrate user datasets";
  }

  @Override
  public boolean isBatchEnabled() {
    return false;
  }

  @Override
  public void execute(SqlSession session) throws Exception {
    FungiDatasetMapper mapper = session.getMapper(FungiDatasetMapper.class);

    // delete guest datasets from userlogins4 that have conflict ids with userlogins3 registered users.
    int count = mapper.deleteGuestDatasets();
    LOG.debug(count + " guest datasets deleted.");

    // insert all the new datasets into userlogins4, except ones from users with changed ids.
    count = mapper.insertNewDatasets();
    LOG.debug(count + " new datasets inserted.");

    // insert new datasets for users with changed ids.
    count = mapper.insertDuplicateDatasets();
    LOG.debug(count + " datasets for users with changed ids are inserted.");
  }

}
