package org.apidb.apicommon.model.maintain.users5;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.DeleteUsers3ArchiveMapper;
import org.apidb.apicommon.model.maintain.users5.mapper.DeleteUsers3ArchiveSouthMapper;
import org.apidb.apicommon.model.maintain.users5.mapper.DeleteUsersMapper;
import org.apidb.apicommon.model.maintain.users5.mapper.GuestMapper;

public class ArchiveGuestCleanupTask implements MigrationTask {

  private static final Logger LOG = Logger.getLogger(ArchiveGuestCleanupTask.class);

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
    GuestMapper guestMapper = session.getMapper(GuestMapper.class);
    DeleteUsersMapper archiveMapper = session.getMapper(DeleteUsers3ArchiveMapper.class);
    DeleteUsersMapper southMapper = session.getMapper(DeleteUsers3ArchiveSouthMapper.class);

    // temp guests are guest users that doesn't have any steps.
    LOG.info("Removing temp guests from userlogins3_archive...");
    TaskUtility.prepareTempUsersTable(session);
    int count = guestMapper.findTempGuests3Archive();
    LOG.debug(count + " guests to be deleted.");
    TaskUtility.deleteUsers(archiveMapper);
    session.commit();

    // temp guests are guest users that doesn't have any steps.
    LOG.info("Removing temp guests from userlogins3_archive_south...");
    TaskUtility.prepareTempUsersTable(session);
    count = guestMapper.findTempGuests3ArchiveSouth();
    LOG.debug(count + " guests to be deleted.");
    TaskUtility.deleteUsers(southMapper);
    session.commit();
  }
}
