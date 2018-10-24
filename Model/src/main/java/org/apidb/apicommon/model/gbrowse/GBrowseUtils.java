package org.apidb.apicommon.model.gbrowse;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.nio.file.DirectoryIteratorException;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.nio.file.attribute.PosixFilePermission;
import java.nio.file.attribute.PosixFilePermissions;
import java.sql.Types;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

import org.apache.log4j.Logger;
import org.gusdb.fgputil.EncryptionUtil;
import org.gusdb.fgputil.IoUtil;
import org.gusdb.fgputil.Tuples.TwoTuple;
import org.gusdb.fgputil.Wrapper;
import org.gusdb.fgputil.db.pool.DatabaseInstance;
import org.gusdb.fgputil.db.runner.SQLRunner;
import org.gusdb.fgputil.db.runner.SQLRunnerException;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;

public class GBrowseUtils {
	
  private static final Logger LOG = Logger.getLogger(GBrowseUtils.class);
  private static final String TRACK_SOURCE_PATH_MACRO = "$$TRACK_SOURCE_PATH_MACROS$$";
  private static final String TRACK_NAME_MACRO = "$$TRACK_NAME_MACROS$$";
  private static final String GLOBAL_READ_WRITE_PERMS = "rw-rw-rw-";
  //private static final String GLOBAL_READ_WRITE_EXECUTE_PERMS = "rwxrwxrwx";
  private static final String TOMCAT_USER = "tomcat";

  private static final String SELECT_SESSION_DATA_SQL =
		  "SELECT id, a_session as info " +
          " FROM gbrowseusers.sessions s, gbrowseusers.session_tbl st " +
		  " WHERE s.id = st.sessionid AND username = ?";
  
  private static final String UPDATE_SESSION_DATA_SQL =
		  "UPDATE gbrowseusers.sessions SET a_session = ? WHERE id = ?";
	  
  public static final String USER_TRACK_UPLOAD_BASE_PROP_NAME = "GBROWSE_USER_TRACK_UPLOAD_BASE";

  /**
   * Returns from the GBrowse schema, the information needed to find the user's persisted tracks.
   * @param username
   * @param userDb
   * @return
   * @throws WdkModelException
   */
  public static TwoTuple<String,String> getGBrowseSessionData(String username, DatabaseInstance userDb) throws WdkModelException {
    Wrapper<TwoTuple<String,String>> wrapper = new Wrapper<>();
    try { 
      String selectSessionDataSql = SELECT_SESSION_DATA_SQL;
      new SQLRunner(userDb.getDataSource(), selectSessionDataSql, "select-gbrowse-session-data").executeQuery(
        new Object[]{ username },
        new Integer[]{ Types.VARCHAR },
        resultSet -> {
          if (resultSet.next()) {
        	    TwoTuple<String,String> tuple = new TwoTuple<>(resultSet.getString("id"), resultSet.getString("info"));
            wrapper.set(tuple);
          }
        }
      );
      return wrapper.get();
    }
    catch(SQLRunnerException sre) {
      throw new WdkModelException(sre.getCause().getMessage(), sre.getCause());
    }
    catch(Exception e) {
      throw new WdkModelException(e);
    }
  }
  
  /**
   * Returns the path, in the GBrowse uploaded tracks file system, to the user's uploaded tracks
   * directory.  If the user does not have such a directory (i.e., has never before uploaded a
   * track to GBrowse) one is created for him/her.
   * @param wdkModel
   * @param userId
   * @return
   * @throws WdkModelException
   */
  public static Path getUserTracksDirectory(WdkModel wdkModel, Long userId) throws WdkModelException {  
    String uploadsId = null;
    String projectId = wdkModel.getProjectId();
    String userTracksBase = wdkModel.getProperties().get(USER_TRACK_UPLOAD_BASE_PROP_NAME);
    if (userTracksBase == null) {
      throw new WdkModelException("Could not find GBrowse user tracks directory." +
          " Model property \"" + USER_TRACK_UPLOAD_BASE_PROP_NAME + "\" is not configued.");
    }
    createGBrowseBasePathIfNeeded(userTracksBase);
    String username = userId + "-" + projectId;
    TwoTuple<String,String> tuple = GBrowseUtils.getGBrowseSessionData(username, wdkModel.getUserDb());
    String info = tuple.getValue();
    Pattern pattern = Pattern.compile("'.uploadsid'\\s*=>\\s*'(\\w*)'");
    Matcher matcher = pattern.matcher(info); 
    if (matcher.find()) {
      uploadsId = matcher.group(1);
    }
    if(uploadsId == null) {
    	  uploadsId = addUploadsIdToGBrowseInfo(tuple, wdkModel.getUserDb());
    }
    Path userTracksDir = Paths.get(userTracksBase, uploadsId);
    if(!Files.exists(userTracksDir)) {
    	  try {
    	    IoUtil.createOpenPermsDirectory(userTracksDir);
    	  }
    	  catch(IOException ioe) {
        throw new WdkModelException("Unable to create an uploadsid directory for this user.", ioe);
    	  }
    }
    return userTracksDir;
  }
  
  /**
   * Returns an imitation of the GBrowse uploads id assigned to each user.
   * @return
   */
  public static String createUploadsIdValue() {
	Long threadId = Thread.currentThread().getId();
	String currentTime = Instant.now().toString();
    return EncryptionUtil.encrypt(currentTime + threadId.toString());
  }
  
  /**
   * Places a freshly created uploads id into the CLOB in the database for this user which defined all the
   * GBrowse settings for this user.
   * @param tuple - contains the gbrowse session and the CLOB for a given user
   * @param userDb
   * @return
   * @throws WdkModelException
   */
  public static String addUploadsIdToGBrowseInfo(TwoTuple<String,String> tuple, DatabaseInstance userDb) throws WdkModelException {
	String uploadsId = createUploadsIdValue();  
    String uploadsIdKeyValue = "'.uploadsid' => '" + createUploadsIdValue() + "',";
    String info = tuple.getValue();
    String infoWithUploadId = info.replaceFirst("^(\\$D\\s*=\\s*\\{)", "$1" + uploadsIdKeyValue);
    try {
      new SQLRunner(userDb.getDataSource(), UPDATE_SESSION_DATA_SQL, "update_gbrowse_session_data").executeUpdate(
            new Object[]{ infoWithUploadId, tuple.getKey() },
            new Integer[]{ Types.CLOB, Types.VARCHAR });
    }
    catch(SQLRunnerException sre) {
    	  WdkModelException.unwrap(sre); 
    }
    return uploadsId;
  }
  
  /**
   * Returns a map of all the tracks found for the given user in the GBrowse uploaded tracks file system
   * along with their status.  An empty map is returned if the user has no uploads directory as yet in the 
   * file system.
   * @param wdkModel
   * @param userId
   * @return
   * @throws WdkModelException
   */
  public static Map<String, GBrowseTrackStatus> getTracksStatus(WdkModel wdkModel, Long userId) throws WdkModelException {
    Path userTracksDir = getUserTracksDirectory(wdkModel, userId);
    if(userTracksDir == null || !Files.exists(userTracksDir)) {
      return new HashMap<>();
    }
    return getTracksStatus(userTracksDir);
  }
  
  /**
   * Returns a map of all the tracks found for the given user in the GBrowse uploaded tracks file system
   * along with their status.
   * @param userTracksDir - directory where user's uploaded tracks are located
   * @return
   * @throws WdkModelException
   */
  public static Map<String, GBrowseTrackStatus> getTracksStatus(Path userTracksDir) throws WdkModelException {
    LOG.debug("In GBrowseUtils!!!!!!!!! \n");
    Map<String, GBrowseTrackStatus> tracksStatus = new HashMap<>();
    try (DirectoryStream<Path> directoryStream = Files.newDirectoryStream(userTracksDir)) {
      for (Path path : directoryStream) {
    	    String trackName = path.getFileName().toString();
          LOG.debug("In GBrowseUtils: getTrackStatus: trackName: " + trackName + "\n");
    	    Path trackStatusPath = Paths.get(path.toString(), GBrowseTrackStatus.TRACK_STATUS_FILE_NAME);
    	    if(Files.exists(trackStatusPath)) {
            String line = "";
    	      try (BufferedReader reader = Files.newBufferedReader(trackStatusPath)) {
    	        line = reader.readLine();
    	      }  
    	   	  catch (IOException x) {
    	    	    throw new WdkModelException(x);
    	    	  }
    	      String status = line.split(":")[0].trim();
    	      String errorMessage = line.split(":").length > 1 ? line.split(":")[1].trim() : "";
    	      LocalDateTime uploadDate = UploadStatus.COMPLETED.name().equals(status) ?
            Instant.ofEpochMilli(trackStatusPath.toFile().lastModified())
            .atZone(ZoneId.systemDefault())
            .toLocalDateTime() : null;  
          tracksStatus.put(trackName, new GBrowseTrackStatus(trackName, status, errorMessage, uploadDate));
    	    }
      }
    }
    catch (IOException | DirectoryIteratorException e) {
      throw new WdkModelException(e);
    }
		LOG.debug("Returning trackStatus: " + tracksStatus) ;
    return tracksStatus;
  }

  /**
   * Convenience method for setting POSIX permissions.
   * @param path
   * @param permissions
   * @return
   * @throws IOException
   */
  public static Path setPosixPermissions(Path path, String permissions) throws IOException {
    Set<PosixFilePermission> perms = PosixFilePermissions.fromString(permissions);
    try {
      Files.setPosixFilePermissions(path, perms);
    }
    catch (UnsupportedOperationException ex) {
      LOG.warn("Cannot set " + permissions + " permissions to " + path);
    }
    return path;
  }

  /**
   * Creates and returns a track name by splicing the user dataset id in between the root
   * of the datafile name and the extension, using a dash to separate the dataset id from
   * the root (e.g., myDataFile.bigwig -> myDataFile-12345.bigwig).  The datafile is uploaded
   * to the GBrowse uploaded track file system in this manner so as to avoid possible name
   * collisions.
   * @param datasetId
   * @param dataFileName
   * @return
   */
  public static String composeTrackName(String datasetId, String dataFileName) {
	if(dataFileName.contains(".")) {
      String dataFileExtension = dataFileName.substring(dataFileName.lastIndexOf("."));
      String rootDataFileName = dataFileName.substring(0, dataFileName.lastIndexOf("."));
      return rootDataFileName + "-" + datasetId + dataFileExtension;
	}
	else {
      return dataFileName + "-" + datasetId;
	}
  }
  
  /**
   * Extracts the datafile name from its track name.
   * @param trackName
   * @return
   */
  public static String composeDatafileName(String trackName) {
	if(trackName.contains(".")) {
      String dataFileExtension = trackName.substring(trackName.lastIndexOf("."));
      String rootDataFileName = trackName.substring(0, trackName.lastIndexOf("-"));
      return rootDataFileName + dataFileExtension;
	}
	else {
	  return trackName.substring(0, trackName.lastIndexOf("-"));
	}
  }
  
  /**
   * 
   * @param userTracksDir
   * @param trackName
   * @param configurationFileData
   * @throws WdkModelException
   */
  public static String assembleGBrowseTrackUploadScaffold(String userTracksDir, String trackName, String CONFIGURATION_TEMPLATE)
  throws WdkModelException {
    String trackPath = Paths.get(userTracksDir, trackName).toString();
    try {

      // This directory likely already exists for error'd/in progress tracks
      IoUtil.createOpenPermsDirectory(Paths.get(trackPath), true);
      
      // Create status file is necessary and set it to in progress.
	  manageStatusFile(userTracksDir, trackName, UploadStatus.IN_PROGRESS, "");
  
      // This directory likely already exists for error'd/in progress tracks
      IoUtil.createOpenPermsDirectory(Paths.get(trackPath, "SOURCES"), true);
      
      Path trackSourcePath = Paths.get(trackPath, "SOURCES", trackName);
  
      // This is a vanilla configuration file that assumes the datafile type to
      // be that of a bigwig file.
      String configurationFileData = CONFIGURATION_TEMPLATE
              .replace(TRACK_SOURCE_PATH_MACRO, trackSourcePath.toString())
              .replace(TRACK_NAME_MACRO, trackName);
      Path configurationFilePath = Paths.get(trackPath, trackName + ".conf");

      // Truncates and re-writes the file for error'd/in progress tracks
      Files.write(configurationFilePath, configurationFileData.getBytes());
      GBrowseUtils.setPosixPermissions(configurationFilePath, GLOBAL_READ_WRITE_PERMS);
      return trackSourcePath.toString();
    }
    catch(IOException ioe) {
    	  // Report any error in the status file.
  	  manageStatusFile(userTracksDir, trackName, UploadStatus.ERROR, "Unable to create the custom track: " + trackName);
  	  throw new WdkModelException("Unable to create the custom track: " + trackName, ioe);
    }
  }


  /**
   * Create the track status file as needed and populate it with the current status and any error msg.
   * @param trackPath
   * @param status
   * @param msg
   * @throws WdkModelException
   */
  public static void manageStatusFile(String userTracksDir, String trackName, UploadStatus status, String msg) throws WdkModelException {
    Path trackStatusFilePath = Paths.get(userTracksDir, trackName, GBrowseTrackStatus.TRACK_STATUS_FILE_NAME);
    try {
  	  Files.write(trackStatusFilePath, (status + " : " + msg).getBytes(), StandardOpenOption.CREATE);
      GBrowseUtils.setPosixPermissions(trackStatusFilePath, GLOBAL_READ_WRITE_PERMS);
    }  
    catch (IOException ioe) {
      throw new WdkModelException(ioe);
    }
  }
  
  /**
   * Returns a list of the name of those tracks which have either been successfully uploaded or in the process of
   * being uploaded.  These tracks are not eligible for a subsequent upload.
   * @param userTracksDir - location of the user's upload tracks directory
   * @return - list of names of tracks ineligible for upload
   * @throws WdkModelException
   */
  public static List<String> identifyTrackNamesIneligibleForUpload(String userTracksDir) throws WdkModelException {
    Map<String, GBrowseTrackStatus> tracksStatus = GBrowseUtils.getTracksStatus(Paths.get(userTracksDir));  
    return tracksStatus.values().stream()
      .filter(ts -> UploadStatus.COMPLETED.name().equals(ts.getStatusIndicator()) ||
	  	            UploadStatus.IN_PROGRESS.name().equals(ts.getStatusIndicator()))
      .map(ts -> ts.getName()).collect(Collectors.toList());
  }
  
  public static void createGBrowseBasePathIfNeeded(String userTracksBase) throws WdkModelException {
    Path path = Paths.get(userTracksBase);
    if(Files.exists(path)) return;
    File dir = new File(userTracksBase);
    boolean successful = dir.mkdirs();
    if(!successful) {
    	  throw new WdkModelException("Unable to create the full GBrowse base path.");
    }
    try {
      while(path != null && Files.getOwner(path).getName().contains(TOMCAT_USER)) {
    	    IoUtil.openPosixPermissions(path);
    	    path = path.getParent();
      }
    }
    	catch(IOException ioe) {
      LOG.warn("Couldn't not set posix permissions for path: " + path, ioe);
    }
  }
}
