package org.apidb.apicommon.model.maintain.users5.mapper;


public interface FungiUserMapper {

  int findNewUsers();
  
  int findDuplicateUsers();
  
  int insertNewUsers();
  
  int insertNewRoles();
}
