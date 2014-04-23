package org.apidb.apicommon.model.maintain.users5.mapper;

public interface UtilityMapper {
  
  String selectTableExist(String tableName);
  
  void createTempUsersTable();
  
  int deleteTempUsers();
  
  void createUserMapTable();
  
  void createUserMapIndex1();
  
  int deleteUserMap();

}
