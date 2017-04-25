package org.apidb.apicommon.model.maintain.users5.mapper;

import java.util.List;

import org.apidb.apicommon.model.maintain.users5.StepInfo;

public interface FungiStepMapper {
  
  int deleteGuestSteps();
  
  int deleteOldSteps();
  
  int insertConflictSteps();
  
  int insertNewSteps();
  
  int insertDuplicateUsersConflictSteps();
  
  int insertDuplicateUsersNewSteps();
  
  int updateLeftSteps();
  
  int updateRightSteps();
  
  List<StepInfo> selectCombinedSteps();
  
  int updateStepParams(StepInfo stepInfo);
}
