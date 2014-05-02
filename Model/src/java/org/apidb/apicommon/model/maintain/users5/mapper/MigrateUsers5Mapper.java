package org.apidb.apicommon.model.maintain.users5.mapper;

public interface MigrateUsers5Mapper {

  int insertUsers();
  
  int insertUserRoles();
  
  int insertPreferences();
  
  int insertSteps();
  
  int insertStrategies();
  
  int insertBaskets();
  
  int insertFavorite();
  
  int deleteUnusedSteps();
  
  int insertDatasets();
  
  int insertDatasetValues();

}
