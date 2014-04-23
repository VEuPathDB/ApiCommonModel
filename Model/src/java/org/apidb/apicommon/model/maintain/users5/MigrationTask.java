package org.apidb.apicommon.model.maintain.users5;

import org.apache.ibatis.session.SqlSession;

public interface MigrationTask {
  
  String getDisplay();
  
  boolean isBatchEnabled();
  
  void execute(SqlSession session) throws Exception;
}
