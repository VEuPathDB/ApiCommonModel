package org.apidb.apicommon.model.userdataset;

import java.nio.file.Path;
import java.sql.Types;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import javax.sql.DataSource;

import org.gusdb.fgputil.FormatUtil;
import org.gusdb.fgputil.Tuples.TwoTuple;
import org.gusdb.fgputil.Wrapper;
import org.gusdb.fgputil.db.pool.DatabaseInstance;
import org.gusdb.fgputil.db.runner.SQLRunner;
import org.gusdb.fgputil.db.runner.SQLRunnerException;
import org.gusdb.fgputil.json.JsonType;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.config.ModelConfig;
import org.gusdb.wdk.model.user.dataset.UserDataset;
import org.gusdb.wdk.model.user.dataset.UserDatasetCompatibility;
import org.gusdb.wdk.model.user.dataset.UserDatasetDependency;
import org.gusdb.wdk.model.user.dataset.UserDatasetType;
import org.gusdb.wdk.model.user.dataset.UserDatasetTypeFactory;
import org.gusdb.wdk.model.user.dataset.UserDatasetTypeHandler;
import org.json.JSONArray;

/**
 * Handler for RNA Seq Type user datasets.  Currently only handles datasets containing only
 * tracks intended for display via GBrowse.
 * @author crisl-adm
 *
 */
public class RnaSeqTypeHandler extends UserDatasetTypeHandler {
	
  private static final int WINDOW = 200000;
  
  /**
   * SQL to look up the current genome build for the organism given in this user dataset.
   */
  private static final String SELECT_CURRENT_GENOME_BUILD_SQL =
		  "SELECT MAX(dh.build_number) as current_build " +
          " FROM apidbTuning.datasetPresenter dp," +
          "      apidbTuning.DatasetHistory dh, " +
          "      apidb.organism o " +
          " WHERE dh.DATASET_PRESENTER_ID = dp.dataset_presenter_id " +
          "  AND o.name_for_filenames = ? " +
          "  AND dp.name = o.abbrev || '_primary_genome_RSRC'";
	
  /**
   * SQL to look up the longest genome sequence available for the genome given in this user
   * dataset.	
   */
  private static final String SELECT_SEQUENCE_SQL =
	      "SELECT gsa.source_id AS seq_id, gsa.length AS length " +
	      " FROM apidbtuning.genomicseqattributes gsa, apidb.organism o, " +
	      "  (SELECT MAX(length) AS ML, taxon_id " +
	      "    FROM apidbtuning.genomicseqattributes " +
	      "    GROUP BY taxon_id ) info" +
	      " WHERE info.taxon_id = gsa.taxon_id " +
	      "  AND info.ml = gsa.length " +
	      "  AND gsa.taxon_id = o.taxon_id " +
	      "  AND ? = o.name_for_filenames ";
	
  @Override
  public UserDatasetCompatibility getCompatibility(UserDataset userDataset, DataSource appDbDataSource) throws WdkModelException {
	TwoTuple<String,Integer> tuple =  getOrganismAndBuildNumberFromDependencies(userDataset);
	int currentBuild = getCurrentGenomeBuildNumber(tuple.getKey(), appDbDataSource);
	boolean match = currentBuild == tuple.getValue();
	return new UserDatasetCompatibility(match,
			match ? "" : "Genome build " + tuple.getValue() + " for organism " + tuple.getKey() + " is no longer supported.");
  }

  @Override
  public UserDatasetType getUserDatasetType() {
    // TODO Auto-generated method stub
    return UserDatasetTypeFactory.getUserDatasetType("RnaSeq", "1.0");
  }

  //TODO For now there is no data file to install in the DB so no command is needed.
  @Override
  public String[] getInstallInAppDbCommand(UserDataset userDataset, Map<String, Path> fileNameToTempFileMap, String projectId) {
    String[] cmd = {};
    return cmd;
  }

  //TODO Only RNASeq tracks for now.  So no files to install in DB.
  @Override
  public Set<String> getInstallInAppDbFileNames(UserDataset userDataset) {
    return new HashSet<String>();
  }

  // TODO For now there is no DB data to uninstall so no command is needed.
  @Override
  public String[] getUninstallInAppDbCommand(Long userDatasetId, String projectId) {
    String[] cmd = {};
    return cmd;
  }

  //TODO For now, there are no relevant questions
  @Override
  public String[] getRelevantQuestionNames() {
    String[] q = {};
    return q;
  }
  
  /**
   * The type specific data here is a JSON Array of genome browser links using the organism cited in the
   * dependency list as the source of a valid reference seq (longest one chosen).  The embedded link is
   * a url encoded link to the service that can stream out the genome browser big wig track represented
   * by that embedded link.
   * 
   */
  @Override
  public JsonType getDetailedTypeSpecificData(WdkModel wdkModel, UserDataset userDataset) throws WdkModelException {
    List<String> links = new ArrayList<>();
    ModelConfig modelConfig = wdkModel.getModelConfig();
    String appUrl = modelConfig.getWebAppUrl();
    Long userId = userDataset.getOwnerId();
    Long datasetId = userDataset.getUserDatasetId();
    String taxonId = getOrganismAndBuildNumberFromDependencies(userDataset).getKey();
    TwoTuple<String,Integer> tuple = getSequenceInfo(taxonId, wdkModel.getAppDb());
    String seqId = tuple.getFirst();
    int length = tuple.getSecond();
    int start = Math.max(0, (length - WINDOW)/2);
    int end = Math.min(length, (length + WINDOW)/2);
    String partialGenomeBrowserUrl = "/cgi-bin/gbrowse/fungidb/?ref=" + seqId + 
        ";start=" + start + ";end=" + end + ";eurl=";
    //TODO This url is subject to change based on security concerns.
    String partialServiceUrl = appUrl + "/service/users/" + userId + "/user-datasets/" + datasetId;

    // Created a new link for each bigwig data track found (determined by extension only) in the user
    // dataset datafiles collection.
    for(String dataFileName : userDataset.getFiles().keySet()) {
      if(isBigWigFile(dataFileName)) {
        String serviceUrl = partialServiceUrl + "/user-datafiles/" + dataFileName;
        String link = partialGenomeBrowserUrl + FormatUtil.urlEncodeUtf8(serviceUrl);
        links.add(link);
      }
    }
    return new JsonType(new JSONArray(links.toArray()));
  }

  /**
   * A SQL lookup needed to obtain the current genome build for the organism provided.
   * @param taxonId - organism id
   * @param appDb
   * @return
   * @throws WdkModelException
   */
  protected Integer getCurrentGenomeBuildNumber(String taxonId, DataSource appDbDataSource) throws WdkModelException {
    Wrapper<Integer> wrapper = new Wrapper<>();
    try { 
      String selectCurrentGenomeBuildSql = SELECT_CURRENT_GENOME_BUILD_SQL;
      new SQLRunner(appDbDataSource, selectCurrentGenomeBuildSql, "select-current-genome-build-by-taxon").executeQuery(
        new Object[]{ taxonId },
        new Integer[]{ Types.VARCHAR },
        resultSet -> {
          if (resultSet.next()) {
            wrapper.set(resultSet.getInt("current_build"));
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
   * A SQL lookup needed to obtain the longest seq id for the organism provided.
   * @param taxonId
   * @param appDb
   * @return
   * @throws WdkModelException
   */
  protected TwoTuple<String,Integer> getSequenceInfo(String taxonId, DatabaseInstance appDb) throws WdkModelException {
    TwoTuple<String, Integer> tuple = new TwoTuple<>(null, null);
    try { 
      String selectSequenceSql = SELECT_SEQUENCE_SQL;
      new SQLRunner(appDb.getDataSource(), selectSequenceSql, "select-sequence-by-taxon").executeQuery(
        new Object[]{ taxonId },
        new Integer[]{ Types.VARCHAR },
        resultSet -> {
          if (resultSet.next()) {
            tuple.set(resultSet.getString("seq_id"), resultSet.getInt("length"));
          }
        }
      );
      return tuple;
    }
    catch(SQLRunnerException sre) {
      throw new WdkModelException(sre.getCause().getMessage(), sre.getCause());
    }
    catch(Exception e) {
      throw new WdkModelException(e);
    }
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
	return dataFileName.endsWith(".bigwig");
  }

}
