package org.apidb.apicommon.model.param;

import org.apache.log4j.Logger;
import org.gusdb.wdk.model.WdkUserException;
import org.gusdb.wdk.model.dataset.AbstractDatasetIterator;
import org.gusdb.wdk.model.dataset.AbstractDatasetParser;
import org.gusdb.wdk.model.dataset.DatasetContents;
import org.gusdb.wdk.model.dataset.DatasetFactory;

import java.util.HashMap;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * @author jerric
 */
public class GffSpanDatasetParser extends AbstractDatasetParser {

  private static final Logger logger = Logger.getLogger(GffSpanDatasetParser.class);

  private static final String PROP_ATTRIBUTES = "gff.attributes";

  public GffSpanDatasetParser() {
    setName("gff");
    setDisplay("GFF");
    setDescription("The input is GFF file format. Only the record rows will be parsed.");
  }

  @Override
  public DatasetIterator iterator(final DatasetContents contents) {
    return new Iterator(contents);
  }

  private class Iterator extends AbstractDatasetIterator {
    private final int     COL_COUNT   = 9;
    private final Pattern COL_DIV_PAT = Pattern.compile("\t");
    private final char    COL_DIV     = '\t';

    Iterator(DatasetContents contents) {
      super(contents, "\r\n?|\n");
    }

    @Override
    protected boolean rowFilter(final String row) {
      if (row.isEmpty() || row.charAt(0) != '#')
        return false;

      return row.chars().filter(c -> c == COL_DIV).count() == COL_COUNT - 1;
    }

    @Override
    protected boolean atEndOfInput(final String row) {
      return row.charAt(0) == '>';
    }

    @Override
    protected String[] parseRow(final String row) throws WdkUserException {
      var attributes = getAttributes();
      var projectId  = param.getWdkModel().getProjectId();

      logger.debug("attributes: " + attributes);

      String[] columns = COL_DIV_PAT.split(row);
      String[] out     = new String[attributes.size() + 2];

      // column 0 is for sequence id, 3 is for start, 4, is for end, 6 is for forward/revise
      out[0] = columns[0] + ":" + columns[3] + "-" + columns[4] + ":" +
        (columns[6].equals("+") ? "f" : "r");
      out[1] = projectId;

      // parsing attributes
      for (String tuple : columns[8].split(";")) {
        String[] pieces = tuple.split("=");
        String attr = pieces[0].toLowerCase();
        if (attributes.containsKey(attr)) {
          out[attributes.get(attr) + 2] = pieces[1];
        }
      }

      return out;
    }

    /**
     * get the acceptable attribute names to be parsed.
     *
     * if the set is empty, don't parse any attribute.
     *
     * the attribute names are converted to lower case.
     */
    private Map<String, Integer> getAttributes() throws WdkUserException {
      String attrs = properties.get(PROP_ATTRIBUTES);
      Map<String, Integer> attributes = new HashMap<>();
      if (attrs == null)
        return attributes;
      int i = 0;
      for (String attr : attrs.split(",")) {
        attr = attr.trim().toLowerCase();
        if (!attr.isEmpty())
          attributes.put(attr, i++);
      }

      int allowedSize = DatasetFactory.MAX_VALUE_COLUMNS - 2;

      if (attributes.size() >= allowedSize)
        throw new WdkUserException(
          "Only " + allowedSize + " attributes are allowed, but "
            + attributes.size() + " attributes are declared: " + attrs
            + " in datasetParam " + param.getFullName()
        );

      return attributes;
    }

  }
}
