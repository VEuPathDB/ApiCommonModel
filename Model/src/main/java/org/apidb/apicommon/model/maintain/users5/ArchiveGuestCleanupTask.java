package org.apidb.apicommon.model.maintain.users5;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.DeleteUsers3ArchiveMapper;
import org.apidb.apicommon.model.maintain.users5.mapper.DeleteUsers3ArchiveSouthMapper;
import org.apidb.apicommon.model.maintain.users5.mapper.DeleteUsersMapper;
import org.apidb.apicommon.model.maintain.users5.mapper.GuestMapper;

public class ArchiveGuestCleanupTask implements MigrationTask {

  private static final Logger LOG = Logger.getLogger(ArchiveGuestCleanupTask.class);
  
  private static final String ARCHIVE_SCHEMA = "userlogins3_archive";
  private static final String SOUTH_SCHEMA = "userlogins3_archive_south";

  private int archiveCount;
  private int southCount;
  
  @Override
  public String getDisplay() {
    return "Remove archive guests";
  }

  @Override
  public boolean isBatchEnabled() {
    return false;
  }

  @Override
  public void execute(SqlSession session) throws Exception {
    GuestMapper mapper = session.getMapper(GuestMapper.class);
    DeleteUsersMapper archiveMapper = session.getMapper(DeleteUsers3ArchiveMapper.class);
    DeleteUsersMapper southMapper = session.getMapper(DeleteUsers3ArchiveSouthMapper.class);
    
    // before doing anything, will get registered user count for later validation
    archiveCount = mapper.selectRegisteredUserCount(ARCHIVE_SCHEMA);
    southCount = mapper.selectRegisteredUserCount(SOUTH_SCHEMA);

    // temp guests are guest users that doesn't have any steps.
    LOG.info("Removing temp guests from "+ARCHIVE_SCHEMA+"...");
    TaskUtility.prepareTempUsersTable(session);
    int count = mapper.findTempGuests3Archive();
    LOG.debug(count + " guests to be deleted.");
    TaskUtility.deleteUsers(archiveMapper);
    session.commit();

    // temp guests are guest users that doesn't have any steps.
    LOG.info("Removing temp guests from "+SOUTH_SCHEMA+"...");
    TaskUtility.prepareTempUsersTable(session);
    count = mapper.findTempGuests3ArchiveSouth();
    LOG.debug(count + " guests to be deleted.");
    TaskUtility.deleteUsers(southMapper);
    session.commit();
  }

  @Override
  public boolean validate(SqlSession session) {
    GuestMapper mapper = session.getMapper(GuestMapper.class);
    
    int newArchiveCount = mapper.selectRegisteredUserCount(ARCHIVE_SCHEMA);
    if (archiveCount != newArchiveCount) {
      LOG.error("Registered users are mistakenly removed from " + ARCHIVE_SCHEMA);
      return false;
    }
    
    int newSouthCount = mapper.selectRegisteredUserCount(SOUTH_SCHEMA);
    if (southCount != newSouthCount) {
      LOG.error("Registered user are mistakenly removed from " + SOUTH_SCHEMA);
      return false;
    }
    return true;
  }
}
