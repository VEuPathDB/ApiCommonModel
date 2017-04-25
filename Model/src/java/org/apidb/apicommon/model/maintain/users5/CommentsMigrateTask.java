/**
 * 
 */
package org.apidb.apicommon.model.maintain.users5;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.MigrateCommentsMapper;

/**
 * @author Jerric
 *
 */
public class CommentsMigrateTask implements MigrationTask {

  private static final Logger LOG = Logger.getLogger(CommentsMigrateTask.class);

  /* (non-Javadoc)
   * @see org.apidb.apicommon.model.maintain.users5.MigrationTask#getDisplay()
   */
  @Override
  public String getDisplay() {
    return "Migrate comments to userlogins5";
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
    MigrateCommentsMapper mapper = session.getMapper(MigrateCommentsMapper.class);
    
    LOG.info("Migrating comments from comments2 to userlogins5...");
    
    int count = mapper.insertReviewStatus();
    LOG.debug(count + " review status migrated.");
    
    count = mapper.insertTargets();
    LOG.debug(count + " targets migrated.");
    
    count = mapper.insertComments();
    LOG.debug(count + " comments migrated.");
    
    count = mapper.insertTargetCategories();
    LOG.debug(count + " categories migrated.");
    
    count = mapper.insertCommentTargetCategories();
    LOG.debug(count + " comment categories migrated.");
    
    count = mapper.insertExternalDBs();
    LOG.debug(count + " external DBs migrated.");
    
    count = mapper.insertLocations();
    LOG.debug(count + " locations migrated.");

    count = mapper.insertCommentExternalDBs();
    LOG.debug(count + " comment external DBs migrated.");
    
    count = mapper.insertReferences();
    LOG.debug(count + " references migrated.");
    
    count = mapper.insertSequences();
    LOG.debug(count + " sequences migrated.");
    
    count = mapper.insertFiles();
    LOG.debug(count + " files migrated.");
    
    count = mapper.insertStableIds();
    LOG.debug(count + " stable ids migrated.");
  }

  @Override
  public boolean validate(SqlSession session) {
    // TODO - need to add validations later
    return true;
  }

}
