package org.apidb.apicommon.model.maintain.users5;

import java.util.Date;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.DeleteUsers3Mapper;
import org.apidb.apicommon.model.maintain.users5.mapper.DeleteUsers4Mapper;
import org.apidb.apicommon.model.maintain.users5.mapper.GuestMapper;

public class GuestCleanupTask implements MigrationTask, CutoffDateAware {

  private static final Logger LOG = Logger.getLogger(GuestCleanupTask.class);

  private Date cutoffDate;
  
  public GuestCleanupTask() {
  }
  
  @Override
  public String getDisplay() {
    return "Remove guests";
  }

  @Override
  public boolean isBatchEnabled() {
    return false;
  }
  
  @Override
  public void setCutoffDate(Date cutoffDate) {
    this.cutoffDate = cutoffDate;
  }

  @Override
  public void execute(SqlSession session) throws Exception {
    GuestMapper mapper = session.getMapper(GuestMapper.class);
    DeleteUsers4Mapper users4Mapper = session.getMapper(DeleteUsers4Mapper.class);
    DeleteUsers3Mapper users3Mapper = session.getMapper(DeleteUsers3Mapper.class);

    // temp guests are the guest users that doesn't have any steps; and any temp guests created before the
    // cutoff date will be deleted.
    LOG.info("Removing temp guests from userlogins4...");
    TaskUtility.prepareTempUsersTable(session);
    int count = mapper.findTempGuests4(cutoffDate);
    LOG.debug(count + " guests to be deleted.");
    TaskUtility.deleteUsers(users4Mapper);
    session.commit();

    LOG.info("Removing temp guests from userlogins3...");
    TaskUtility.prepareTempUsersTable(session);
    count = mapper.findTempGuests3(cutoffDate);
    LOG.debug(count + " guests to be deleted.");
    TaskUtility.deleteUsers(users3Mapper);
    session.commit();

    // conflicting guests are the guests users in userlogins4 that have the same user_id as the registered
    // users in the userlogins3.
    LOG.info("Removing conflicting guests from userlogins4...");
    TaskUtility.prepareTempUsersTable(session);
    count = mapper.findConflictGuest4();
    LOG.debug(count + " guests to be deleted.");
    TaskUtility.deleteUsers(users4Mapper);
    session.commit();

    // conflicting guests are the guests users in userlogins3 that have the same user_id as the registered
    // users in the userlogins4.
    LOG.info("Removing conflicting guests from userlogins3...");
    TaskUtility.prepareTempUsersTable(session);
    count = mapper.findConflictGuest3();
    LOG.debug(count + " guests to be deleted.");
    TaskUtility.deleteUsers(users3Mapper);
    session.commit();
  }
}
