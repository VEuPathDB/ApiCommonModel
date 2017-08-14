package org.apidb.apicommon.model.param;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.StringReader;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.apache.log4j.Logger;
import org.gusdb.wdk.model.dataset.AbstractDatasetParser;
import org.gusdb.wdk.model.dataset.DatasetFactory;
import org.gusdb.wdk.model.dataset.WdkDatasetException;

/**
 * @author jerric
 */
public class GffSpanDatasetParser extends AbstractDatasetParser {

  private static final String PROP_ATTRIBUTES = "gff.attributes";

  private static final Logger logger = Logger.getLogger(GffSpanDatasetParser.class);

  public GffSpanDatasetParser() {
    setName("gff");
    setDisplay("GFF");
    setDescription("The input is GFF file format. Only the record rows will be parsed.");
  }

  /*
   * (non-Javadoc)
   * 
   * @see org.gusdb.wdk.model.dataset.DatasetParser#parse(java.lang.String)
   */
  @Override
  public List<String[]> parse(String content) throws WdkDatasetException {
    Map<String, Integer> attributes = getAttributes();
    List<String[]> data = new ArrayList<>();

    logger.debug("attributes: " + attributes);

    String projectId = param.getWdkModel().getProjectId();
    BufferedReader reader = new BufferedReader(new StringReader(content));
    String line;
    try {
      while ((line = reader.readLine()) != null) {
        line = line.trim();
        if (line.length() == 0 || line.startsWith("#"))
          continue;
        if (line.startsWith(">")) // reaching sequence section, stop.
          break;
        String[] columns = line.split("\t");
        // if the number of columns are not 9, skip it - not a valid gff line
        if (columns.length != 9)
          continue;

        String[] row = new String[attributes.size() + 2];
        // column 0 is for sequence id, 3 is for start, 4, is for end, 6 is for forward/revise
        row[0] = columns[0] + ":" + columns[3] + "-" + columns[4] + ":" +
            (columns[6].equals("+") ? "f" : "r");
        row[1] = projectId;

        // parsing attributes
        for (String tuple : columns[8].split(";")) {
          String[] pieces = tuple.split("=");
          String attr = pieces[0].toLowerCase();
          if (attributes.containsKey(attr)) {
            row[attributes.get(attr) + 2] = pieces[1];
          }
        }
        data.add(row);
      }
    }
    catch (IOException ex) {
      throw new WdkDatasetException(ex);
    }

    return data;
  }

  /**
   * get the acceptable attribute names to be parsed. if the set is empty, don't parse any attribute.
   * 
   * the attribute names are converted to lower case.
   * 
   * @return
   * @throws WdkDatasetException
   */
  private Map<String, Integer> getAttributes() throws WdkDatasetException {
    String attrs = properties.get(PROP_ATTRIBUTES);
    Map<String, Integer> attributes = new HashMap<>();
    if (attrs == null)
      return attributes;
    int i = 0;
    for (String attr : attrs.split(",")) {
      attr = attr.trim().toLowerCase();
      if (attr.length() > 0)
        attributes.put(attr, i++);
    }
    int allowedSize = DatasetFactory.MAX_VALUE_COLUMNS - 2;
    if (attributes.size() >= allowedSize)
      throw new WdkDatasetException("Only " + allowedSize + " attributes are allowed, but " +
          attributes.size() + " attributes are declared: " + attrs + " in datasetParam " +
          param.getFullName());
    return attributes;
  }
}
