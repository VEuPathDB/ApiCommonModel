package org.apidb.apicommon.model.maintain.users5.mapper;

public interface FungiStrategyMapper {
  
  int deleteGuestStrategies();
  
  int deleteGuestStrategiesByRoot();
  
  int deleteOldStrategies();
  
  int insertConflictStrategies();
  
  int insertNewStrategies();
  
  int insertDuplicateUsersConflictStrategies();
  
  int insertDuplicateUsersNewStrategies();
  
  int updateRootSteps();
}
