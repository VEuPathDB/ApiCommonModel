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
import org.gusdb.fgputil.Wrapper;
import org.gusdb.fgputil.db.pool.DatabaseInstance;
import org.gusdb.fgputil.db.runner.SQLRunner;
import org.gusdb.fgputil.db.runner.SQLRunnerException;
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

public class RnaSeqTypeHandler extends UserDatasetTypeHandler {
	
  private static final String SELECT_SEQUENCE_SQL =
	      "SELECT gsa.source_id AS seq_id " +
	      " FROM apidbtuning.genomicseqattributes gsa, apidb.organism o, " +
	      "  (SELECT MAX(length) AS ML, taxon_id " +
	      "    FROM apidbtuning.genomicseqattributes " +
	      "    GROUP BY taxon_id ) info" +
	      " WHERE info.taxon_id = gsa.taxon_id " +
	      "  AND info.ml = gsa.length " +
	      "  AND gsa.taxon_id = o.taxon_id " +
	      "  AND ? = o.name_for_filenames ";
	
  @Override
  public UserDatasetCompatibility getCompatibility(UserDataset userDataset, DataSource appDbDataSource) {
    // TODO Auto-generated method stub
    return null;
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
    String[] cmd = {"uninstallRnaSeqUserDataset", userDatasetId.toString(), projectId};
    return cmd;
  }

  //TODO For now, there are no relevant questions
  @Override
  public String[] getRelevantQuestionNames() {
    String[] q = {};
    return q;
  }
  
  /**
   * The ancillary data here is a JSON Array of genome browser links using the organism cited in the
   * dependency list as the source of a valid reference seq (longest one chosen).  The embedded link is
   * a url encoded link to the service that can stream out the genome browser big wig track represented
   * by that embedded link.
   * 
   */
  @Override
  public String getTrackSpecificData(WdkModel wdkModel, UserDataset userDataset) throws WdkModelException {
	List<String> links = new ArrayList<>();
	ModelConfig modelConfig = wdkModel.getModelConfig();
	String appUrl = modelConfig.getWebAppUrl();
	Long userId = userDataset.getOwnerId();
	Long datasetId = userDataset.getUserDatasetId();
	Set<UserDatasetDependency> dependencies = userDataset.getDependencies();
	if(dependencies == null || dependencies.size() != 1) {
	  throw new WdkModelException("Exactly one dependency is needed for this handler.");
	}
	UserDatasetDependency dependency = (UserDatasetDependency) dependencies.toArray()[0];
	String resourceIdentifier = dependency.getResourceIdentifier();
    String taxonId = getTaxonId(resourceIdentifier);
    String seqId = getSequenceId(taxonId, wdkModel.getAppDb());
    //TODO Is there a better way to just grab the host?
    String partialGenomeBrowserUrl = "/cgi-bin/gbrowse/fungidb/?ref=" + seqId + ";eurl=";
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
	return new JSONArray(links.toArray()).toString();
  }
  
  /**
   * A SQL lookup needed to obtain the longest seq id for the organism provided.
   * @param taxonId
   * @param appDb
   * @return
   * @throws WdkModelException
   */
  private String getSequenceId(String taxonId, DatabaseInstance appDb) throws WdkModelException {
    Wrapper<String> wrapper = new Wrapper<>();
    try {  
      String selectSequenceSql = SELECT_SEQUENCE_SQL;
      new SQLRunner(appDb.getDataSource(), selectSequenceSql, "select-sequence-by-taxon").executeQuery(
        new Object[]{ taxonId },
        new Integer[]{ Types.VARCHAR },
        resultSet -> {
          if (resultSet.next()) {
            wrapper.set(resultSet.getString("seq_id"));
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
   * This convenience method extracts the abbreviated taxon id from the resource identifier
   * provided.  By convention, the resource identifier looks like projectId-buildNumber_taxonId_Genome
   * If the resource identifier is no in this format, a WdkModelException will be thrown.
   * @param resourceIdentifier
   * @return
   * @throws WdkModelException
   */
  protected String getTaxonId(String resourceIdentifier)  throws WdkModelException {
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
