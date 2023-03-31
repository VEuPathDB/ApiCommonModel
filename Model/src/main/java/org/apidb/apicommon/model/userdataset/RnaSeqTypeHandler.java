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
  private final static String DISPLAY = "RNA-Seq";

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
      Path manifestFile = fileNameToTempFileMap.get("manifest.txt");
      if (manifestFile == null) {
	  throw new RuntimeException("failed to get manifest.txt");
      }
      
      String[] cmd = {"installRnaSeqUserDataset", userDataset.getUserDatasetId().toString(), manifestFile.toString(), projectId};
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
  public String[] getRelevantQuestionNames(UserDataset userDataset) {

      boolean isStranded = false;
      try {
          Set<String> files = userDataset.getFiles().keySet();

          for(String s : files) {
              if(s.endsWith("-forward.bw")) {
                  isStranded = true;
              }
          }
      }
      catch(WdkModelException e) {
          throw new RuntimeException("Error Getting all files for this dataset: " + e.toString());
      }
//     //use contents of manifest file to determine strandedness:
//      try {
//        // this doesn't work:
//	  File  manifestFile = userDataset.getFiles().get("manifest.txt").getFilePath().toFile();
//	  BufferedReader reader = new BufferedReader(new FileReader(manifestFile));

//	  String currentLine;
//	  while ( (currentLine = reader.readLine()) != null) {
//	      if (currentLine.endsWith("sense")) {
//		  isStranded = true;
//	      }
//	  }
	      

//      }
//      catch(WdkModelException e) {
//          throw new RuntimeException("Error getting all files for this dataset: " + e.toString());
//      }
//      catch(FileNotFoundException e) {
//          throw new RuntimeException("Error opening the manifest file of this dataset: " + e.toString());
//      }
//      catch(IOException e) {
//          throw new RuntimeException("Error opening the manifest file of this dataset: " + e.toString());
//      }

      String[] qList;
      String[] unstrandedQList = {"GeneQuestions.GenesByRNASeqUserDataset"};
      // String[] strandedQList = {"GeneQuestions.GenesByRNASeqUserDataset", "GeneQuestions.GenesByUserDatasetAntisense"};
      String[] strandedQList = {"GeneQuestions.GenesByRNASeqUserDataset"};
      if (isStranded) {
	  qList = strandedQList;
      } else {
	  qList = unstrandedQList;
      }

//      String[] qList = {"GeneQuestions.GenesByRNASeqUserDataset", "GeneQuestions.GenesByUserDatasetAntisense"};

      return qList;
  }

  @Override
  protected boolean isBigWigFile(String dataFileName) {
	return dataFileName.endsWith(".bigwig") || dataFileName.endsWith(".bw");
  }


  // @Override
  // public UserDatasetCompatibility getCompatibility(UserDataset userDataset, DataSource appDbDataSource) {
  //     // TODO Placeholder - need real compatibility test
  //     return new UserDatasetCompatibility(true, "");
  // }

}
