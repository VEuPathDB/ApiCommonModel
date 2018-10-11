package org.apidb.apicommon.model.userdataset;

import java.nio.file.Path;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.user.dataset.UserDataset;
import org.gusdb.wdk.model.user.dataset.UserDatasetType;
import org.gusdb.wdk.model.user.dataset.UserDatasetTypeFactory;

public class RnaSeqTypeHandler extends BigwigFilesTypeHandler {

  private final static String NAME = "RnaSeq";
  private final static String VERSION = "1.0";
  private final static String DISPLAY = "RNASeq";

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

      try {
          Set<String> files = userDataset.getFiles().keySet();
          Set<String> textFiles = new HashSet<String>();

          for(String s : files) {
              if(s.endsWith("txt")) {
                  textFiles.add(s);
              }
          }
          return textFiles;
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
    String[] q = {"GeneQuestions.GenesByRNASeqUserDataset"};
    return q;
  }

  // @Override
  // public UserDatasetCompatibility getCompatibility(UserDataset userDataset, DataSource appDbDataSource) {
  //     // TODO Placeholder - need real compatibility test
  //     return new UserDatasetCompatibility(true, "");
  // }

}
