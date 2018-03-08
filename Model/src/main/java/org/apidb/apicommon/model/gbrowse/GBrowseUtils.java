package org.apidb.apicommon.model.gbrowse;

import java.io.IOException;
import java.nio.file.DirectoryIteratorException;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.attribute.PosixFilePermission;
import java.nio.file.attribute.PosixFilePermissions;
import java.sql.Types;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

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
import org.gusdb.wdk.model.config.ModelConfig;

public class GBrowseUtils {
	
  private static final Logger LOG = Logger.getLogger(GBrowseUtils.class);
	
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
  
  public static Path getUserTracksDirectory(WdkModel wdkModel, Long userId) throws WdkModelException {  
    String uploadsId = null;
    String projectId = wdkModel.getProjectId();
    String userTracksBase = wdkModel.getProperties().get(USER_TRACK_UPLOAD_BASE_PROP_NAME);
    if (userTracksBase == null) {
      throw new WdkModelException("Could not find GBrowse user tracks directory." +
          " Model property \"" + USER_TRACK_UPLOAD_BASE_PROP_NAME + "\" is not configued.");
    }
    ModelConfig modelConfig = wdkModel.getModelConfig();
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
  
  public static String createUploadsIdValue() {
	Long threadId = Thread.currentThread().getId();
	String currentTime = Instant.now().toString();
    return EncryptionUtil.encrypt(currentTime + threadId.toString());
  }
  
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
   * Gets a list of the GBrowse tracks for the given user that are already persisted in the
   * file system.
   * @param wdkModel
   * @param userId
   * @return
   * @throws WdkModelException
   */
  public static Map<String,LocalDateTime> getPersistedTracks(WdkModel wdkModel, Long userId) throws WdkModelException {
    Path userTracksDir = getUserTracksDirectory(wdkModel, userId);
    if(userTracksDir == null || !Files.exists(userTracksDir)) {
      return new HashMap<>();
    }
    return getPersistedTracks(userTracksDir);
  }
  
  public static Map<String, LocalDateTime> getPersistedTracks(Path userTracksDir) throws WdkModelException {
    Map<String, LocalDateTime> persistedTracks = new HashMap<>();
    try (DirectoryStream<Path> directoryStream = Files.newDirectoryStream(userTracksDir)) {
      for (Path path : directoryStream) {
    	    LocalDateTime date =
          Instant.ofEpochMilli(path.toFile().lastModified()).atZone(ZoneId.systemDefault()).toLocalDateTime();
        persistedTracks.put(path.getFileName().toString(), date);
      }
    }
    catch (IOException | DirectoryIteratorException e) {
      throw new WdkModelException(e);
    }
    return persistedTracks;
  }

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

  public static String composeTrackName(String url) throws WdkModelException {
	String datasetId = "";
    Pattern pattern = Pattern.compile("\\/user-datasets\\/(\\d+)\\/");
    Matcher matcher = pattern.matcher(url); 
    if (matcher.find()) {
      datasetId = matcher.group(1);
    }
    else {
    	  throw new WdkModelException("The embedded url does not contain a dataset id.");
    }
    String dataFileName = url.substring(url.lastIndexOf("/") + 1);
    String dataFileExtension = dataFileName.substring(dataFileName.lastIndexOf("."));
    String rootDataFileName = dataFileName.substring(0, dataFileName.lastIndexOf("."));
    return rootDataFileName + "-" + datasetId + dataFileExtension;   
  }

}
