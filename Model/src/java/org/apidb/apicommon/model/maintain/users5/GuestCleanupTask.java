package org.apidb.apicommon.model.maintain.users5;

import java.util.Date;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.DeleteUsers3Mapper;
import org.apidb.apicommon.model.maintain.users5.mapper.DeleteUsers4Mapper;
import org.apidb.apicommon.model.maintain.users5.mapper.GuestMapper;

public class GuestCleanupTask implements MigrationTask, CutoffDateAware {

  private static final Logger LOG = Logger.getLogger(GuestCleanupTask.class);
  
  private static final String USER3_SCHEMA = "userlogins3";
  private static final String USER4_SCHEMA = "userlogins4";

  private Date cutoffDate;
  private int user3Count;
  private int user4Count;
  
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
    
    
    // before doing anything, will get registered user count for later validation
    user3Count = mapper.selectRegisteredUserCount(USER3_SCHEMA);
    user4Count = mapper.selectRegisteredUserCount(USER4_SCHEMA);


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
  
  @Override
  public boolean validate(SqlSession session) {
    GuestMapper mapper = session.getMapper(GuestMapper.class);
    
    int newUser3Count = mapper.selectRegisteredUserCount(USER3_SCHEMA);
    if (user3Count != newUser3Count) {
      LOG.error("Registered users are mistakenly removed from " + USER3_SCHEMA);
      return false;
    }
    
    int newUser4Count = mapper.selectRegisteredUserCount(USER4_SCHEMA);
    if (user4Count != newUser4Count) {
      LOG.error("Registered user are mistakenly removed from " + USER4_SCHEMA);
      return false;
    }
    return true;
  }
}
