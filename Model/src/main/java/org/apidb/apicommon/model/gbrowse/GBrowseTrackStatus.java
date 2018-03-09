package org.apidb.apicommon.model.gbrowse;

import java.time.LocalDateTime;

/**
 * Simple POJO to gather together status information for a track in the GBrowse uploaded track file system.
 * The name is the name of the track.  The statusIndicator and the errorMessage (if any) originate with a
 * track status text file that is included with each track upload service attempt.
 * @author crisl-adm
 *
 */
public class GBrowseTrackStatus {

  public static final String TRACK_STATUS_FILE_NAME = "track_status.txt";
	
  private String _name;	
  private String _statusIndicator;
  private String _errorMessage;
  private LocalDateTime _uploadedDate;
		  
  public GBrowseTrackStatus(String name, String statusIndicator, String errorMessage, LocalDateTime uploadedDate) {
    _name = name;
    _statusIndicator = statusIndicator;
    _errorMessage = errorMessage;
    _uploadedDate = uploadedDate;
  }
  
  public String getName() {
    return _name;
  }

  public String getStatusIndicator() {
    return _statusIndicator;
  }

  public String getErrorMessage() {
    return _errorMessage;
  }

  public LocalDateTime getUploadedDate() {
    return _uploadedDate;
  }
}
