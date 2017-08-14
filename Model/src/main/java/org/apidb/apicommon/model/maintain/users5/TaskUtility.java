package org.apidb.apicommon.model.maintain.users5;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.DeleteUsersMapper;
import org.apidb.apicommon.model.maintain.users5.mapper.UtilityMapper;

public class TaskUtility {

  private static final String TEMP_USERS_TABLE = "temp_users";
  private static final String USER_MAP_TABLE = "user_map";

  private static final Logger LOG = Logger.getLogger(TaskUtility.class);

  public static boolean isTableExist(SqlSession session, String tableName) {
    UtilityMapper mapper = session.getMapper(UtilityMapper.class);
    return isTableExist(mapper, tableName);
  }

  private static boolean isTableExist(UtilityMapper mapper, String tableName) {
    String name = mapper.selectTableExist(tableName);
    return (name != null);
  }

  public static void prepareTempUsersTable(SqlSession session) {
    UtilityMapper mapper = session.getMapper(UtilityMapper.class);
    if (null == mapper.selectTableExist(TEMP_USERS_TABLE)) {
      mapper.createTempUsersTable();
    }
    mapper.deleteTempUsers();
  }

  public static void prepareUserMapTable(SqlSession session) {
    UtilityMapper mapper = session.getMapper(UtilityMapper.class);
    if (null == mapper.selectTableExist(USER_MAP_TABLE)) {
      mapper.createUserMapTable();
      mapper.createUserMapIndex1();
    }
    mapper.deleteUserMap();
  }

  public static void deleteUsers(DeleteUsersMapper mapper) {
    int count = mapper.deleteBaskets();
    LOG.debug(count + " basket rows deleted.");
    count = mapper.deleteDatasets();
    LOG.debug(count + " dataset rows deleted.");
    count = mapper.deleteFavorites();
    LOG.debug(count + " favorite rows deleted.");
    count = mapper.deletePreferences();
    LOG.debug(count + " preference rows deleted.");
    count = mapper.deleteRoles();
    LOG.debug(count + " user_role rows deleted.");
    count = mapper.deleteStrategies();
    LOG.debug(count + " strategy rows deleted.");
    count = mapper.deleteSteps();
    LOG.debug(count + " step rows deleted.");
    count = mapper.deleteUsers();
    LOG.debug(count + " user rows deleted.");
  }
}
