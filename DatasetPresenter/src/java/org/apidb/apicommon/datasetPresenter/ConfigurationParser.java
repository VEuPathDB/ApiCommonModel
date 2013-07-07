package org.apidb.apicommon.datasetPresenter;

import java.io.File;
import java.io.IOException;

import org.apache.commons.digester.Digester;
import org.gusdb.fgputil.xml.Text;
import org.gusdb.fgputil.xml.XmlParser;
import org.xml.sax.SAXException;

/**
 * 
 */
public class ConfigurationParser extends XmlParser {

  public ConfigurationParser() {
    // use the wrong .rng file.   it is not worth it for now to make a right one
    super(System.getenv("GUS_HOME") + "/lib/rng/datasetPresenter.rng", false);
  }

  @Override
  protected Digester configureDigester() {
    Digester digester = new Digester();
    digester.setValidating(false);

    digester.addObjectCreate("tuningProps", Configuration.class);


    configureNode(digester, "tuningProps/password",
        Text.class, "setPassword");
    digester.addCallMethod("tuningProps/password",
        "setText", 0);
    
    configureNode(digester, "tuningProps/schema",
        Text.class, "setUsername");
    digester.addCallMethod("tuningProps/schema",
        "setText", 0);

    return digester;
  }

  Configuration parseFile(String xmlFileName) {

   Configuration config = null;
    try {
      configure();
      config = (Configuration) digester.parse(new File(
          xmlFileName));
      if (config.getPassword() == null) throw new UserException("Could not parse password out of tuning manager prop XML file " + xmlFileName);
      if (config.getUsername() == null) throw new UserException("Could not parse schema out of tuning manager prop XML file " + xmlFileName);
    } catch (IOException | SAXException ex) {
      throw new UnexpectedException(ex);
    }
    return config;
  }

}
