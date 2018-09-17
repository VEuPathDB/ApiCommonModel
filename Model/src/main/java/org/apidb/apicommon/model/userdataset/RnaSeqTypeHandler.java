package org.apidb.apicommon.model.userdataset;

import java.nio.file.Path;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import javax.sql.DataSource;

import org.gusdb.wdk.model.user.dataset.UserDataset;
import org.gusdb.wdk.model.user.dataset.UserDatasetCompatibility;
import org.gusdb.wdk.model.user.dataset.UserDatasetType;
import org.gusdb.wdk.model.user.dataset.UserDatasetTypeFactory;
import org.gusdb.wdk.model.user.dataset.UserDatasetTypeHandler;
import org.gusdb.wdk.model.user.dataset.UserDatasetFile;

import org.gusdb.wdk.model.WdkModelException;

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
    String[] cmd = {"installRnaSeqUserDataset", userDataset.getUserDatasetId().toString(), fileNameToTempFileMap.get("manifest.txt").toString(), projectId};
    return cmd;
  }

  @Override
  public Set<String> getInstallInAppDbFileNames(UserDataset userDataset) {

      //    Set<String> filenames = new HashSet<String>();
    //    filenames.add();


      try {
          return userDataset.getFiles().keySet();
      }
      catch(WdkModelException e) {
          throw new RuntimeException("Error Getting all files for this dataset: " + e.toString());
      }
  }

  @Override
  public String[] getUninstallInAppDbCommand(Long userDatasetId, String projectId) {
    String[] cmd = {"uninstallRnaSeqUserDataset", userDatasetId.toString(), projectId};
    return cmd;
  }

  @Override
  public String[] getRelevantQuestionNames() {
      // TODO
    String[] q = {};
    return q;
  }

  @Override
  public UserDatasetCompatibility getCompatibility(UserDataset userDataset, DataSource appDbDataSource) {
      // TODO Placeholder - need real compatibility test
      return new UserDatasetCompatibility(true, "");
  }

}
