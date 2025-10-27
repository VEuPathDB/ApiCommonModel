package org.apidb.apicommon.model.userdataset;

import static org.gusdb.fgputil.functional.Functions.fSwallow;
import static org.gusdb.fgputil.functional.Functions.mapToList;

import java.nio.file.Path;
import java.sql.Types;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import javax.sql.DataSource;

import org.apache.log4j.Logger;
import org.apidb.apicommon.model.userdataset.TrackDatasetUtil.TrackData;
import org.gusdb.fgputil.Tuples.TwoTuple;
import org.gusdb.fgputil.db.pool.DatabaseInstance;
import org.gusdb.fgputil.db.runner.SQLRunner;
import org.gusdb.fgputil.json.JsonType;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.user.User;
import org.gusdb.wdk.model.user.dataset.UserDataset;
import org.gusdb.wdk.model.user.dataset.UserDatasetCompatibility;
import org.gusdb.wdk.model.user.dataset.UserDatasetDependency;
import org.gusdb.wdk.model.user.dataset.UserDatasetType;
import org.gusdb.wdk.model.user.dataset.UserDatasetTypeFactory;
import org.gusdb.wdk.model.user.dataset.UserDatasetTypeHandler;
import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Handler for Bigwig Files Type user datasets.  Currently only handles datasets
 * containing only tracks intended for display via GBrowse.
 *
 * @author crisl-adm
 *
 */
public class BigwigFilesTypeHandler extends UserDatasetTypeHandler {

  private static final Logger logger = Logger.getLogger(BigwigFilesTypeHandler.class);

  private final static String NAME = "BigwigFiles";
  private final static String VERSION = "1.0";
  private final static String DISPLAY = "Bigwig";

  /**
   * SQL to look up the current genome build for the organism given in this user dataset.
   *     it is the last time/build when the annotation_version got updated (there was a structural annotation).
   */
  private static final String SELECT_CURRENT_GENOME_BUILD_SQL =
      "SELECT MAX(build_number) as current_build " +
      "FROM (" +
          "SELECT dh.build_number, annotation_version, " +
          "       LAG(annotation_version ,1, 0) OVER (order by dh.build_number) as av_prev " +
          " FROM apidbTuning.datasetPresenter dp," +
          "      apidbTuning.DatasetHistory dh, " +
          "      apidb.organism o " +
          " WHERE dh.DATASET_PRESENTER_ID = dp.dataset_presenter_id " +
          "  AND o.name_for_filenames = ? " +
          "  AND dp.name = o.abbrev || '_primary_genome_RSRC'" +
      ")" +
      "WHERE annotation_version != av_prev ";

  /**
   * SQL to look up the longest genome sequence available for the genome given in this user
   * dataset.	
   */
  private static final String SELECT_SEQUENCE_SQL =
      "SELECT gsa.source_id AS seq_id, gsa.length AS length " +
      " FROM webready.GenomicSeqAttributes_p gsa, apidb.organism o, " +
      "  (SELECT MAX(length) AS ML, taxon_id " +
      "    FROM webready.GenomicSeqAttributes_p " +
      "    GROUP BY taxon_id ) info" +
      " WHERE info.taxon_id = gsa.taxon_id " +
      "  AND info.ml = gsa.length " +
      "  AND gsa.taxon_id = o.taxon_id " +
      "  AND ? = o.name_for_filenames ";

  @Override
  public UserDatasetCompatibility getCompatibility(UserDataset userDataset, DataSource appDbDataSource) throws WdkModelException {
    TwoTuple<String,Integer> tuple =  getOrganismAndBuildNumberFromDependencies(userDataset);
    int currentBuild = getCurrentGenomeBuildNumber(tuple.getKey(), appDbDataSource);
    logger.debug("CURRENT BUILD IS:" + currentBuild);
    boolean match = currentBuild <= tuple.getValue();
    return new UserDatasetCompatibility(match, new JSONObject().put("currentBuild", currentBuild),
        match ? "" : "Genome build " + tuple.getValue() + " for organism " + tuple.getKey() + " is no longer supported. Current build " + currentBuild);
  }

  @Override
  public UserDatasetType getUserDatasetType() {
    return UserDatasetTypeFactory.getUserDatasetType(NAME, VERSION);
  }

  @Override
  public String getDisplay() {
    return DISPLAY;
  }

  @Override
  public String[] getInstallInAppDbCommand(UserDataset userDataset, Map<String, Path> fileNameToTempFileMap, String projectId, Path workingDir) {
    String[] cmd = {};
    return cmd;
  }

  // Nothing to install in DB.
  @Override
  public Set<String> getInstallInAppDbFileNames(UserDataset userDataset) {
    return new HashSet<String>();
  }

  // Nothing to uninstall so no command is needed.
  @Override
  public String[] getUninstallInAppDbCommand(Long userDatasetId, String projectId) {
    String[] cmd = {};
    return cmd;
  }

  // There are no relevant questions
  @Override
  public String[] getRelevantQuestionNames(UserDataset userDataset) {
    String[] q = {};
    return q;
  }

  @Override
  public List<JsonType> getTypeSpecificData(WdkModel wdkModel, List<UserDataset> userDatasets, User user) throws WdkModelException {
    return mapToList(userDatasets, fSwallow(userDataset -> (new JsonType(createTrackData(userDataset)))));
  }

  /**
   * The type specific data here is a JSON Array of genome browser links using the organism cited in the
   * dependency list as the source of a valid reference seq (longest one chosen).  The embedded link is
   * a url encoded link to the service that can stream out the genome browser big wig track represented
   * by that embedded link.
   */
  @Override
  public JsonType getDetailedTypeSpecificData(WdkModel wdkModel, UserDataset userDataset, User user) throws WdkModelException {
    JSONObject json =  new JSONObject()
        .put("tracks",createTrackData(userDataset))
        .put("seqId", getSequenceInfo(userDataset, wdkModel).getFirst());
    return new JsonType(json);
  }

  public JSONArray createTrackData(UserDataset userDataset) throws WdkModelException {
    List<TrackData> tracksData = new ArrayList<>();
    Long datasetId = userDataset.getUserDatasetId();

    // Created new track data for each bigwig data track found (determined by extension only) in the user
    // dataset datafiles collection.
    for (String dataFileName : userDataset.getFiles().keySet()) {
      if (isBigWigFile(dataFileName)) {
        String trackName = TrackDatasetUtil.composeTrackName(datasetId.toString(), dataFileName);
        tracksData.add(new TrackData(trackName));
      }
    }
    JSONArray results = assembleTracksDataJson(tracksData);
    return results;
  }

  protected JSONArray assembleTracksDataJson(List<TrackData> tracksData) {
    JSONArray tracks = new JSONArray();  
    for (TrackData trackData : tracksData) {
      tracks.put(trackData.assembleJson());
    }
    return tracks;
  }

  /**
   * A SQL lookup needed to obtain the current genome build for the organism provided.
   * @param taxonId - organism id
   * @param appDb
   * @return
   * @throws WdkModelException
   */
  protected Integer getCurrentGenomeBuildNumber(String taxonId, DataSource appDbDataSource) throws WdkModelException {
    logger.debug("TAXONID:" + taxonId);
    try { 
      return new SQLRunner(appDbDataSource, SELECT_CURRENT_GENOME_BUILD_SQL,
          "select-current-genome-build-by-taxon").executeQuery(
        new Object[]{ taxonId },
        new Integer[]{ Types.VARCHAR },
        resultSet -> resultSet.next() ? resultSet.getInt("current_build") : null
      );
    }
    catch(Exception e) {
      return WdkModelException.unwrap(e);
    }
  }

  /**
   * A SQL lookup needed to obtain the longest seq id for the organism provided.
   * 
   * @param taxonId
   * @param appDb
   * @return
   * @throws WdkModelException
   */
  protected TwoTuple<String,Integer> getSequenceInfo(String taxonId, DatabaseInstance appDb) throws WdkModelException {
    try { 
      return new SQLRunner(appDb.getDataSource(), SELECT_SEQUENCE_SQL,
          "select-sequence-by-taxon").executeQuery(
        new Object[]{ taxonId },
        new Integer[]{ Types.VARCHAR },
        resultSet -> resultSet.next() ?
            new TwoTuple<>(resultSet.getString("seq_id"), resultSet.getInt("length")) :
            new TwoTuple<>(null, null)
      );
    }
    catch(Exception e) {
      return WdkModelException.unwrap(e);
    }
  }

  protected TwoTuple<String,Integer> getSequenceInfo(UserDataset userDataset, WdkModel wdkModel) throws WdkModelException {
    Set<UserDatasetDependency> dependencies = userDataset.getDependencies();
    if(dependencies == null || dependencies.size() != 1) {
      throw new WdkModelException("Exactly one dependency is needed for this handler.");
    }
    UserDatasetDependency dependency = (UserDatasetDependency) dependencies.toArray()[0];
    String resourceIdentifier = dependency.getResourceIdentifier();
    return getSequenceInfo(extractTaxonId(resourceIdentifier), wdkModel.getAppDb());
  }

  /**
   * The dependency list is expected presently to have just 1 dependency and that is the
   * current genome build for the organism.  Both are obtained 
   * @param userDataset
   * @return
   * @throws WdkModelException
   */
  protected TwoTuple<String, Integer> getOrganismAndBuildNumberFromDependencies(UserDataset userDataset) throws WdkModelException {
    Set<UserDatasetDependency> dependencies = userDataset.getDependencies();
    if(dependencies == null || dependencies.size() != 1) {
      throw new WdkModelException("Exactly one dependency is needed for this handler.");
    }
    UserDatasetDependency dependency = (UserDatasetDependency) dependencies.toArray()[0];
    String resourceIdentifier = dependency.getResourceIdentifier();
    String resourceVersion = dependency.getResourceVersion();
    Integer buildNumber = 0;
    if(resourceIdentifier == null || resourceVersion == null)
      throw new WdkModelException("The dependency information for user dataset " + userDataset.getUserDatasetId()  + " is incomplete.");
    try {
      buildNumber = Integer.parseInt(resourceVersion);
    }
    catch(NumberFormatException nfe) {
      throw new WdkModelException("The dependency resource version for user dataset " + userDataset.getUserDatasetId() + " must be a WDK build number");
    }
    return new TwoTuple<String,Integer>(extractTaxonId(resourceIdentifier), buildNumber);
  }

  /**
   * This convenience method extracts the abbreviated taxon id from the resource identifier
   * provided.  By convention, the resource identifier looks like projectId-buildNumber_taxonId_Genome
   * If the resource identifier is no in this format, a WdkModelException will be thrown.
   * @param resourceIdentifier
   * @return
   * @throws WdkModelException
   */
  protected String extractTaxonId(String resourceIdentifier)  throws WdkModelException {
    String sansProject = resourceIdentifier.substring(resourceIdentifier.indexOf("-") + 1);
    String[] components = sansProject.split("_");
    if(components.length < 2) {
      throw new WdkModelException("The user datasets resource identifier " + resourceIdentifier + " does not follow the expected convention.");
    }
    return components[1]; 
  }
  
  /**
   * Identifying bigwig files by the .bigwig extension only.  We could add more if needed (like .bw).
   * @param dataFileName
   * @return
   */
  protected boolean isBigWigFile(String dataFileName) {
      return true;
  }

}
