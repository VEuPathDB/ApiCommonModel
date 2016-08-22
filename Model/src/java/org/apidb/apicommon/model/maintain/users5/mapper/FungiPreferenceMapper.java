package org.apidb.apicommon.model.maintain.users5.mapper;

public interface FungiPreferenceMapper {

  int deletePreferences();
  
  int insertExistingPreferences();
  
  int insertNewPreferences();
  
  int insertDuplicatePreferences();
  
}
