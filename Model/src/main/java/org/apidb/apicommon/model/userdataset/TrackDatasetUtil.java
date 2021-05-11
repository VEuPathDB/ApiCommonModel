package org.apidb.apicommon.model.userdataset;

import org.json.JSONObject;

class TrackDatasetUtil {

  // static class
  private TrackDatasetUtil() { }

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
  static String composeTrackName(String datasetId, String dataFileName) {
    if (dataFileName.contains(".")) {
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
  static String composeDatafileName(String trackName) {
    if (trackName.contains(".")) {
      String dataFileExtension = trackName.substring(trackName.lastIndexOf("."));
      String rootDataFileName = trackName.substring(0, trackName.lastIndexOf("-"));
      return rootDataFileName + dataFileExtension;
    }
    else {
      return trackName.substring(0, trackName.lastIndexOf("-"));
    }
  }

  static class TrackData {

    String _trackName;

    TrackData(String trackName) {
      _trackName = trackName;
    }

    JSONObject assembleJson() {
      return new JSONObject().put("trackName", _trackName);
    }
  }
}
