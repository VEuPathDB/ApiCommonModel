package org.apidb.apicommon.datasetInjector;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.digester.Digester;
import org.gusdb.fgputil.xml.NamedValue;
import org.gusdb.fgputil.xml.Text;
import org.gusdb.fgputil.xml.XmlParser;
import org.xml.sax.SAXException;

/**
 * Parse an XML representation of a DatasetPresenterSet into java objects. The
 * XML schema is described in lib/rng/datasetPresenter.rng.
 */
public class DatasetPresenterParser extends XmlParser {

  public DatasetPresenterParser() {
    super(System.getenv("GUS_HOME") + "/lib/rng/datasetPresenter.rng", false);
  }

  protected Digester configureDigester() {
    Digester digester = new Digester();
    digester.setValidating(false);

    digester.addObjectCreate("datasetPresenters", DatasetPresenterSet.class);

    configureNode(digester, "datasetPresenters/datasetPresenter",
        DatasetPresenter.class, "addDatasetPresenter");

    configureNode(digester, "datasetPresenters/datasetPresenter/description",
        Text.class, "setDatasetDescrip");
    digester.addCallMethod("datasetPresenters/datasetPresenter/description",
        "setText", 0);

    configureNode(digester,
        "datasetPresenters/datasetPresenter/templateInjector",
        DatasetInjectorConstructor.class, "addDatasetInjector");

    configureNode(digester,
        "datasetPresenters/datasetPresenter/templateInjector/prop",
        NamedValue.class, "addProp");
    digester.addCallMethod(
        "datasetPresenters/datasetPresenter/templateInjector/prop", "setValue",
        0);

    return digester;
  }


  DatasetPresenterSet parseFile(String xmlFileName) {

    DatasetPresenterSet datasetPresenterSet = null;
    try {
      configure();
      datasetPresenterSet = (DatasetPresenterSet)digester.parse(new File(xmlFileName));
    } catch (IOException | SAXException ex) {
      throw new UnexpectedException(ex);
    }
    return datasetPresenterSet;
  }

  DatasetPresenterSet parseDir(String presenterXmlDirPath) {
    DatasetPresenterSet bigDatasetPresenterSet = new DatasetPresenterSet();
    List<File> presenterFiles = getPresenterXmlFilesInDir(presenterXmlDirPath);
    for (File presenterFile : presenterFiles) {
      bigDatasetPresenterSet.addDatasetPresenterSet(parseFile(presenterXmlDirPath + "/" + presenterFile.getName()));
    }

    return bigDatasetPresenterSet;
  }

static List<File> getPresenterXmlFilesInDir(String presentersDirPath) {
  File dir = new File(presentersDirPath);
  List<File> presenterFiles = new ArrayList<File>();

  for (File file : dir.listFiles()) {
    if (file.isFile() && file.getName().endsWith(".xml"))
      presenterFiles.add(file);
  }
  return presenterFiles;
}


}



