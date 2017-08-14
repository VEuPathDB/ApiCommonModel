package org.apidb.apicommon.model.maintain.users5.mapper;

public interface DeleteCommentsMapper {

  int deleteStableIds();
  
  int deleteFiles();
  
  int deleteSequences();
  
  int deleteReferences();
  
  int deleteCommentTargetCategories();
  
  int deleteTargetCategories();
  
  int deleteCommentExternalDBs();
  
  int deleteLocations();
  
  int deleteExternalDBs();
  
  int deleteComments();
  
  int deleteReviewStatus();
  
  int deleteTargets();
}
