package org.apidb.apicommon.model.maintain.users5.mapper;

public interface MigrateCommentsMapper {

  int insertTargets();
  
  int insertReviewStatus();
  
  int insertComments();
  
  int insertExternalDBs();
  
  int insertLocations();
  
  int insertCommentExternalDBs();
  
  int insertTargetCategories();
  
  int insertCommentTargetCategories();
  
  int insertReferences();
  
  int insertSequences();
  
  int insertFiles();
  
  int insertStableIds();
}
