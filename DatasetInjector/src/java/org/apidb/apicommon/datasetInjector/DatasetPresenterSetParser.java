package org.apidb.apicommon.datasetInjector;

import org.apache.commons.digester.Digester;
import org.gusdb.fgputil.xml.NamedValue;
import org.gusdb.fgputil.xml.Text;
import org.gusdb.fgputil.xml.XmlParser;

public class DatasetPresenterSetParser  extends XmlParser {
  
  public DatasetPresenterSetParser() {
    super("lib/rng/workflow.rng");
}

  protected Digester configureDigester() {
    Digester digester = new Digester();
    digester.setValidating(false);
    
    digester.addObjectCreate("datasetPresenters", DatasetPresenterSet.class);

    configureNode(digester, "datasetPresenters/datasetPresenter", DatasetPresenter.class, "addDatasetPresenter");

    configureNode(digester, "datasetPresenters/datasetPresenter/description", Text.class, "addDatasetDescrip");
    digester.addCallMethod("datasetPresenters/datasetPresenter/description", "setText", 0);
    
    configureNode(digester, "datasetPresenters/datasetPresenter/templateInjector", DatasetInjectorConstructor.class, "addDatasetInjector");

    configureNode(digester, "datasetPresenters/datasetPresenter/templateInjector/prop", NamedValue.class, "addProp");
    digester.addCallMethod("datasetPresenters/datasetPresenter/templateInjector/prop", "setValue", 0);

   return digester;
}

}
