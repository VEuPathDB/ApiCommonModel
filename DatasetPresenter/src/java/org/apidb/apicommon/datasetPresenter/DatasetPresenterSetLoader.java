package org.apidb.apicommon.datasetPresenter;

import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.Options;
import org.gusdb.fgputil.CliUtil;

import oracle.jdbc.driver.OracleDriver;

public class DatasetPresenterSetLoader {

  private Contacts allContacts;
  private Connection dbConnection;
  private Configuration config;
  private String instance;
  private String propFileName;
  private String suffix;

  static final String nl = System.lineSeparator();

  public DatasetPresenterSetLoader(String propFileName,
      String contactsFileName, String instance, String suffix) {
    ConfigurationParser configParser = new ConfigurationParser();
    config = configParser.parseFile(propFileName);
    ContactsFileParser contactsParser = new ContactsFileParser();
    allContacts = contactsParser.parseFile(contactsFileName);
    this.instance = instance;
    this.propFileName = propFileName;
    this.suffix = suffix;
  }

  void schemaInstall() {
    manageSchema(false);
  }

  void schemaDropConstraints() {
    manageSchema(true);
  }

  void manageSchema(boolean dropConstraints) {
    String mode = dropConstraints ? "-dropConstraints" : "-create";
    String[] cmd = { "presenterCreateSchema", instance, suffix, propFileName, mode };
    Process process;
    try {
      process = Runtime.getRuntime().exec(cmd);
      process.waitFor();
      if (process.exitValue() != 0)
        throw new UserException(
            "Failed running command to create DatasetPresenter schema: "
                + System.lineSeparator() + "presenterCreateSchema "
	    + instance + " " + suffix + " " + propFileName + " " + mode);
      process.destroy();
    } catch (IOException | InterruptedException ex) {
      throw new UnexpectedException(ex);
    }
  }

  // read contacts file and create contacts.
  void loadDatasetPresenterSet(DatasetPresenterSet dps) {
    try {
      initDbConnection();

      PreparedStatement datasetTableStmt = getDatasetTableStmt();
      PreparedStatement presenterStmt = getPresenterStmt();
      PreparedStatement contactStmt = getContactStmt();
      PreparedStatement publicationStmt = getPublicationStmt();
      PreparedStatement referenceStmt = getReferenceStmt();
      PreparedStatement linkStmt = getLinkStmt();
      PreparedStatement taxonStmt = getTaxonStmt();

      for (DatasetPresenter datasetPresenter : dps.getDatasetPresenters()) {

        getPresenterValuesFromDatasetTable(datasetTableStmt, datasetPresenter);

        int datasetPresenterId = getNextDatasetPresenterId();

        loadDatasetPresenter(datasetPresenterId, datasetPresenter,
            presenterStmt);

        for (Contact contact : datasetPresenter.getContacts(allContacts)) {
          loadContact(datasetPresenterId, contact, contactStmt);
        }

        for (Publication pub : datasetPresenter.getPublications()) {
          loadPublication(datasetPresenterId, pub, publicationStmt);
        }

        for (ModelReference ref : datasetPresenter.getModelReferences()) {
          loadModelReference(datasetPresenterId, ref, referenceStmt);
        }

        for (HyperLink link : datasetPresenter.getLinks()) {
          loadLink(datasetPresenterId, link, linkStmt);
        }

        for (Integer taxonId : datasetPresenter.getTaxonIds()) {
          loadTaxon(datasetPresenterId, taxonId, taxonStmt);
        }
      }
    } catch (SQLException e) {
      throw new UnexpectedException(e);
    } finally {
      try {
	if (dbConnection != null) dbConnection.close();
      } catch (SQLException e) {
        throw new UnexpectedException(e);
      }
    }
  }

  PreparedStatement getDatasetTableStmt() throws SQLException {
    String table = config.getUsername() + ".Dataset";
    String sql = "SELECT taxon_id, type, subtype, is_species_scope " + "FROM "
        + table + " WHERE name like ?";
    return dbConnection.prepareStatement(sql);
  }

  PreparedStatement getPresenterStmt() throws SQLException {
    String table = config.getUsername() + ".DatasetPresenter" + suffix;
    String sql = "INSERT INTO "
        + table
        + " (dataset_presenter_id, name, dataset_name_pattern, display_name, short_display_name, summary, protocol, description, caveat, acknowledgement, release_policy, display_category, type, subtype, is_species_scope)"
        + " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
    return dbConnection.prepareStatement(sql);
  }

  private void loadDatasetPresenter(int datasetPresenterId,
      DatasetPresenter datasetPresenter, PreparedStatement stmt)
      throws SQLException {
    stmt.setInt(1, datasetPresenterId);
    stmt.setString(2, datasetPresenter.getDatasetName());
    stmt.setString(3, datasetPresenter.getDatasetNamePattern());
    stmt.setString(4, datasetPresenter.getDatasetDisplayName());
    stmt.setString(5, datasetPresenter.getDatasetShortDisplayName());
    stmt.setString(6, datasetPresenter.getSummary());
    stmt.setString(7, datasetPresenter.getProtocol());
    stmt.setString(8, datasetPresenter.getDatasetDescrip());
    stmt.setString(9, datasetPresenter.getCaveat());
    stmt.setString(10, datasetPresenter.getAcknowledgement());
    stmt.setString(11, datasetPresenter.getReleasePolicy());
    stmt.setString(12, datasetPresenter.getDisplayCategory());
    stmt.setString(13, datasetPresenter.getType());
    stmt.setString(14, datasetPresenter.getSubtype());
    stmt.setBoolean(15, datasetPresenter.getIsSpeciesScope());
    stmt.execute();

  }

  PreparedStatement getContactStmt() throws SQLException {
    String table = config.getUsername() + ".DatasetContact" + suffix;
    String sql = "INSERT INTO "
        + table
        + " (dataset_contact_id, dataset_presenter_id, is_primary_contact, name, email, affiliation, address, city, state, zip, country)"
        + " VALUES (" + table + "_sq.nextval, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
    return dbConnection.prepareStatement(sql);
  }

  private void loadContact(int datasetPresenterId, Contact contact,
      PreparedStatement stmt) throws SQLException {
    stmt.setInt(1, datasetPresenterId);
    stmt.setBoolean(2, contact.getIsPrimary());
    stmt.setString(3, contact.getName());
    stmt.setString(4, contact.getEmail());
    stmt.setString(5, contact.getInstitution());
    stmt.setString(6, contact.getAddress());
    stmt.setString(7, contact.getCity());
    stmt.setString(8, contact.getState());
    stmt.setString(9, contact.getZip());
    stmt.setString(10, contact.getCountry());
    stmt.execute();
  }

  PreparedStatement getPublicationStmt() throws SQLException {
    String table = config.getUsername() + ".DatasetPublication" + suffix;
    String sql = "INSERT INTO " + table
        + " (dataset_publication_id, dataset_presenter_id, pmid, citation)"
        + " VALUES (" + table + "_sq.nextval, ?, ?, ?)";
    return dbConnection.prepareStatement(sql);
  }

  private void loadPublication(int datasetPresenterId, Publication publication,
      PreparedStatement stmt) throws SQLException {
    stmt.setInt(1, datasetPresenterId);
    stmt.setString(2, publication.getPubmedId());
    stmt.setString(3, publication.getCitation());
    stmt.execute();
  }

  PreparedStatement getTaxonStmt() throws SQLException {
    String table = config.getUsername() + ".DatasetTaxon" + suffix;
    String sql = "INSERT INTO " + table
        + " (dataset_taxon_id, dataset_presenter_id, taxon_id)" + " VALUES ("
        + table + "_sq.nextval, ?, ?)";
    return dbConnection.prepareStatement(sql);
  }

  private void loadTaxon(int datasetPresenterId, Integer taxonId,
      PreparedStatement stmt) throws SQLException {
    stmt.setInt(1, datasetPresenterId);
    stmt.setInt(2, taxonId);
    stmt.execute();
  }

  PreparedStatement getReferenceStmt() throws SQLException {
    String table = config.getUsername() + ".DatasetModelRef" + suffix;
    String sql = "INSERT INTO "
        + table
        + " (dataset_model_ref_id, dataset_presenter_id, record_type, target_type, target_name)"
        + " VALUES (" + table + "_sq.nextval, ?, ?, ?, ?)";
    return dbConnection.prepareStatement(sql);
  }

  private void loadModelReference(int datasetPresenterId, ModelReference ref,
      PreparedStatement stmt) throws SQLException {
    stmt.setInt(1, datasetPresenterId);
    stmt.setString(2, ref.getRecordClassName());
    stmt.setString(3, ref.getTargetType());
    stmt.setString(4, ref.getTargetName());
    stmt.execute();
  }

  PreparedStatement getLinkStmt() throws SQLException {
    String table = config.getUsername() + ".DatasetHyperLink" + suffix;
    String sql = "INSERT INTO " + table
        + " (dataset_link_id, dataset_presenter_id, text, url)" + " VALUES ("
        + table + "_sq.nextval, ?, ?, ?)";
    return dbConnection.prepareStatement(sql);
  }

  private void loadLink(int datasetPresenterId, HyperLink link,
      PreparedStatement stmt) throws SQLException {
    stmt.setInt(1, datasetPresenterId);
    stmt.setString(2, link.getText());
    stmt.setString(3, link.getUrl());
    stmt.execute();
  }

  Connection initDbConnection() {
    if (dbConnection == null) {
      String dsn = "jdbc:oracle:oci:@" + instance;
      String login = config.getUsername();
      String password = config.getPassword();
      try {
        DriverManager.registerDriver(new OracleDriver());
        dbConnection = DriverManager.getConnection(dsn, login, password);
      } catch (SQLException e) {
        throw new UserException("Can't connect to instance " + instance
            + " with login info found in config file " + propFileName, e);
      }
    }
    return dbConnection;
  }

  int getNextDatasetPresenterId() throws SQLException {
    String table = config.getUsername() + ".DatasetPresenter" + suffix;
    String sql = "select " + table + "_sq.nextval from dual";
    Statement stmt = null;
    ResultSet rs = null;
    int id;
    try {
      stmt = dbConnection.createStatement();
      rs = stmt.executeQuery(sql);
      rs.next();
      id = rs.getInt(1);
    } finally {
      if (rs != null)
        rs.close();
      if (stmt != null)
        stmt.close();
    }
    return id;
  }

  void getPresenterValuesFromDatasetTable(PreparedStatement stmt,
      DatasetPresenter datasetPresenter) throws SQLException {
    ResultSet rs = null;
    String namePattern = datasetPresenter.getDatasetNamePattern() == null
        ? datasetPresenter.getDatasetName()
        : datasetPresenter.getDatasetNamePattern();
    stmt.setString(1, namePattern);
    String first_type = null;
    String first_subtype = null;
    Boolean first_isSpeciesScope = null;
    boolean foundFirst = false;
    try {

      rs = stmt.executeQuery();
      while (rs.next()) {
        Integer taxonId = rs.getInt(1);
        String type = rs.getString(2);
        String subtype = rs.getString(3);
        Boolean isSpeciesScope = rs.getBoolean(4);
        if (!foundFirst) {
          foundFirst = true;
          first_type = type;
          first_subtype = subtype;
          first_isSpeciesScope = isSpeciesScope;
          datasetPresenter.setType(type);
          datasetPresenter.setSubtype(subtype);
          datasetPresenter.setIsSpeciesScope(isSpeciesScope);
        } else {
          if ((first_type == null && type != null)
              || (first_type != null && !type.equals(first_type))
              || (first_subtype == null && subtype != null)
              || (first_subtype != null && !subtype.equals(first_subtype))
              || (first_isSpeciesScope != isSpeciesScope))
            throw new UserException("DatasetPresenter with datasetNamePattern=\"" + namePattern + "\" matches rows in the Dataset table that disagree in their type, subtype or is_species_scope columns");
        }
        datasetPresenter.addTaxonId(taxonId);
      }
    } finally {
      if (rs != null)
        rs.close();
    }
  }

  // ///////////// Static methods //////////////////////////////

  private static Options declareOptions() {
    Options options = new Options();

    CliUtil.addOption(options, "presentersDir",
        "a directory containing one or more dataset presenter xml files", true,
        true);

    CliUtil.addOption(
        options,
        "contactsXmlFile",
        "an XML file containing contacts (that are referenced in the presenters files)",
        true, true);

    CliUtil.addOption(
        options,
        "tuningPropsXmlFile",
        "an XML file containing database username and password, in the formate expected by the tuning manager",
        true, true);

    CliUtil.addOption(options, "instance",
        "the name of the instance to write to", true, true);

    CliUtil.addOption(
        options,
        "suffix",
        "the suffix to append to all tables created (as is always done in tuning tables",
        true, true);

    return options;
  }

  private static String getUsageNotes() {
    return

    nl + "";
  }

  static CommandLine getCmdLine(String[] args) {
    String cmdName = System.getProperty("cmdName");

    // parse command line
    Options options = declareOptions();
    String cmdlineSyntax = cmdName
        + " -presentersDir presenters_dir -contactsXmlFile contacts_file -tuningPropsXmlFile propFile -instance instance_name -suffix suffix";
    String cmdDescrip = "Read provided dataset presenter files and inject templates into the presentation layer.";
    CommandLine cmdLine = CliUtil.parseOptions(cmdlineSyntax, cmdDescrip,
        getUsageNotes(), options, args);

    return cmdLine;
  }

  public static void main(String[] args) throws Exception {
    CommandLine cmdLine = getCmdLine(args);
    String presentersDir = cmdLine.getOptionValue("presentersDir");
    String contactsFile = cmdLine.getOptionValue("contactsXmlFile");
    String propFile = cmdLine.getOptionValue("tuningPropsXmlFile");
    String instance = cmdLine.getOptionValue("instance");
    String suffix = cmdLine.getOptionValue("suffix");
    try {
      DatasetPresenterSet datasetPresenterSet = DatasetPresenterSet.createFromPresentersDir(presentersDir);
      DatasetPresenterSetLoader dpsl = new DatasetPresenterSetLoader(propFile, contactsFile, instance, suffix);
      dpsl.schemaInstall();
      dpsl.loadDatasetPresenterSet(datasetPresenterSet);
      dpsl.schemaDropConstraints();
    } catch (UserException ex) {
      System.err.println(nl + "Error: " + ex.getMessage() + nl);
      System.exit(1);
    }
  }
}
