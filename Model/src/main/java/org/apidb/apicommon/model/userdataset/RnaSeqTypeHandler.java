package org.apidb.apicommon.model.userdataset;

import java.nio.file.Path;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import javax.sql.DataSource;

import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.user.dataset.UserDataset;
import org.gusdb.wdk.model.user.dataset.UserDatasetCompatibility;
import org.gusdb.wdk.model.user.dataset.UserDatasetType;
import org.gusdb.wdk.model.user.dataset.UserDatasetTypeFactory;
import org.gusdb.wdk.model.user.dataset.UserDatasetTypeHandler;

/**
 * Handler renamed to BigwigFilesTypeHandler.  This one kept as people may still
 * have this handler in their website configuration.
 * @author crisl-adm
 *
 */
@Deprecated
public class RnaSeqTypeHandler extends UserDatasetTypeHandler {

  public final static String NAME = "RnaSeq";
  public final static String VERSION = "1.0";
  public final static String DISPLAY = "RNASeq - Deprecated";

  @Override
  public UserDatasetType getUserDatasetType() {
    return UserDatasetTypeFactory.getUserDatasetType(NAME, VERSION);
  }

  @Override
  public String getDisplay() {
	return DISPLAY;
  }

  @Override
  public String[] getInstallInAppDbCommand(UserDataset userDataset, Map<String, Path> fileNameToTempFileMap, String projectId) {
    String[] cmd = {};
    return cmd;
  }

  @Override
  public Set<String> getInstallInAppDbFileNames(UserDataset userDataset) {
    return new HashSet<String>();
  }

  @Override
  public String[] getUninstallInAppDbCommand(Long userDatasetId, String projectId) {
    String[] cmd = {};
    return cmd;
  }

  @Override
  public String[] getRelevantQuestionNames() {
    String[] q = {};
    return q;
  }

  @Override
  public UserDatasetCompatibility getCompatibility(UserDataset userDataset, DataSource appDbDataSource)
	throws WdkModelException {
	return new UserDatasetCompatibility(false, "This handler is deprecated.");
  }
}
