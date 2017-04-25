package org.apidb.apicommon.model.maintain.users5.mapper;

import java.util.Date;

import org.apache.ibatis.annotations.Param;

public interface GuestMapper {

  int findConflictGuest4();

  int findConflictGuest3();

  int findTempGuests3(Date cutoffDate);

  int findTempGuests4(Date cutoffDate);

  int findTempGuests3Archive();

  int findTempGuests3ArchiveSouth();

  int selectRegisteredUserCount(@Param("schema") String schema);
}
