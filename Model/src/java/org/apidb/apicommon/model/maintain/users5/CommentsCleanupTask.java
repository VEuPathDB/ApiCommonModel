/**
 * 
 */
package org.apidb.apicommon.model.maintain.users5;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.DeleteCommentsMapper;

/**
 * @author Jerric
 *
 */
public class CommentsCleanupTask implements MigrationTask {

  private static final Logger LOG = Logger.getLogger(CommentsCleanupTask.class);

  /*
   * (non-Javadoc)
   * 
   * @see org.apidb.apicommon.model.maintain.users5.MigrationTask#getDisplay()
   */
  @Override
  public String getDisplay() {
    return "Clean up comments from userlogins5";
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
    DeleteCommentsMapper mapper = session.getMapper(DeleteCommentsMapper.class);

    LOG.info("Removing all comments from userlogins5...");

    int count = mapper.deleteStableIds();
    LOG.debug(count + " stable ids deleted.");

    count = mapper.deleteFiles();
    LOG.debug(count + " comment files deleted.");

    count = mapper.deleteSequences();
    LOG.debug(count + " comment sequences deleted.");

    count = mapper.deleteReferences();
    LOG.debug(count + " comment references deleted.");

    count = mapper.deleteCommentTargetCategories();
    LOG.debug(count + " comment categories deleted.");

    count = mapper.deleteTargetCategories();
    LOG.debug(count + " categories deleted.");

    count = mapper.deleteCommentExternalDBs();
    LOG.debug(count + " comment external DBs deleted.");

    count = mapper.deleteLocations();
    LOG.debug(count + " comment locations deleted.");

    count = mapper.deleteExternalDBs();
    LOG.debug(count + " external DBs deleted.");

    count = mapper.deleteComments();
    LOG.debug(count + " comments deleted.");

    count = mapper.deleteReviewStatus();
    LOG.debug(count + " review status deleted.");

    count = mapper.deleteTargets();
    LOG.debug(count + " targets deleted.");
  }

  @Override
  public boolean validate(SqlSession session) {
    // TODO - need to add validations later
    return true;
  }

}
