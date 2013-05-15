package org.apidb.apicommon.datasetPresenter;

import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

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
  private String defaultInjectorsFileName;
  private String suffix;
  private String login;
  private DatasetPresenterSet dps = null;

  static final String nl = System.lineSeparator();

  public DatasetPresenterSetLoader(String propFileName,
      String contactsFileName, String defaultInjectorsFileName,
      String instance, String suffix) {
    ConfigurationParser configParser = new ConfigurationParser();
    config = configParser.parseFile(propFileName);
    ContactsFileParser contactsParser = new ContactsFileParser();
    allContacts = contactsParser.parseFile(contactsFileName);
    this.instance = instance;
    this.propFileName = propFileName;
    this.suffix = suffix;
    this.defaultInjectorsFileName = defaultInjectorsFileName;
  }

  void setDatasetPresenterSet(DatasetPresenterSet dps) {
    this.dps = dps;
  }

  /**
   * 
   * @param dps
   * @return set of dataset names in db not found (or matched by) the
   *         DatasetPresenters in the input set
   */
  Set<String> syncPresenterSetWithDatasetTable() {
    initDbConnection();

    try {
      Set<String> datasetNamesFoundInDb = new HashSet<String>();

      PreparedStatement datasetTableStmt = getDatasetTableStmt();

      for (InternalDataset internalDataset : dps.getInternalDatasets().values()) {
        findInternalDatasetNamesInDb(internalDataset, datasetTableStmt,
            datasetNamesFoundInDb);
      }

      Set<String> presenterNamesNotInDb = new HashSet<String>();
      for (DatasetPresenter datasetPresenter : dps.getDatasetPresenters().values()) {
        getPresenterValuesFromDatasetTable(datasetPresenter, datasetTableStmt,
            datasetNamesFoundInDb);
        if (!datasetPresenter.getFoundInDb())
          presenterNamesNotInDb.add(datasetPresenter.getDatasetName());
        
        datasetPresenter.getContacts(allContacts); // validate contacts
        datasetPresenter.getModelReferences(); // validate model references
      }

      if (presenterNamesNotInDb.size() != 0) {
        System.err.println(nl
            + "The following DatasetPresenters have no match in ApiDB.Dataset: "
            + nl + setToString(presenterNamesNotInDb));
      }
      
      dps.handleOverrides();
      
      Set<String> dbDatasetNamesNotInPresenters = new HashSet<String>(
          findDatasetNamesInDb());

      dbDatasetNamesNotInPresenters.removeAll(datasetNamesFoundInDb);

      return dbDatasetNamesNotInPresenters;
    } catch (SQLException e) {
      throw new UnexpectedException(e);
    }
  }

  Connection initDbConnection() {
    if (dbConnection == null) {
      String dsn = "jdbc:oracle:oci:@" + instance;
      login = config.getUsername();
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

  void findInternalDatasetNamesInDb(InternalDataset internalDataset,
      PreparedStatement stmt, Set<String> datasetNamesFoundInDb)
      throws SQLException {

    Set<String> datasetNamesFoundLocal = new HashSet<String>();
    ResultSet rs = null;
    String namePattern = internalDataset.getDatasetNamePattern() == null
        ? internalDataset.getName() : internalDataset.getDatasetNamePattern();
    stmt.setString(1, namePattern);
    boolean found = false;
    try {
      rs = stmt.executeQuery();
      while (rs.next()) {
        found = true;
        String name = rs.getString(1);
        if (datasetNamesFoundInDb.contains(name))
          throw new UserException(
              "InternalDataset with name \""
                  + internalDataset.getName()
                  + "\" has a name or name pattern that is claimed by another DatasetPresenter or InternalDataset.  The conflicting name is: \""
                  + name + "\"");
        datasetNamesFoundLocal.add(name);
        internalDataset.addNameFromDb(name);
      }
      if (!found) {
          System.err.println("WARN:  InternalDataset with name or pattern \""
            + namePattern + "\" does not match any row in ApiDB.Dataset");
      } 
      else {
          datasetNamesFoundInDb.addAll(datasetNamesFoundLocal);
      }
    } finally {
      if (rs != null)
        rs.close();
    }
  }

  void getPresenterValuesFromDatasetTable(DatasetPresenter datasetPresenter,
      PreparedStatement stmt, Set<String> datasetNamesFoundInDb)
      throws SQLException {
    Set<String> datasetNamesFoundLocal = new HashSet<String>();
    ResultSet rs = null;
    String namePattern = datasetPresenter.getDatasetNamePattern() == null
        ? datasetPresenter.getDatasetName()
        : datasetPresenter.getDatasetNamePattern();
    stmt.setString(1, namePattern);
    String first_type = null;
    String first_subtype = null;
    Boolean first_isSpeciesScope = null;

    try {
      rs = stmt.executeQuery();
      while (rs.next()) {
        String name = rs.getString(1);
        Integer taxonId = rs.getInt(2);
        String type = rs.getString(3);
        String subtype = rs.getString(4);
        Boolean isSpeciesScope = rs.getBoolean(5);
        if (datasetPresenter.getOverride() == null) {
          if (datasetNamesFoundInDb.contains(name))
            throw new UserException(
                "DatasetPresenter with name \""
                    + datasetPresenter.getDatasetName()
                    + "\" has a name or name pattern that is claimed by another DatasetPresenter or InternalDataset.  The conflicting name is: \""
                    + name + "\"");
          datasetNamesFoundLocal.add(name);
        }
        if (!datasetPresenter.getFoundInDb()) {
          datasetPresenter.setFoundInDb();
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
            throw new UserException(
                "DatasetPresenter with datasetNamePattern=\""
                    + namePattern
                    + "\" matches rows in the Dataset table that disagree in their type, subtype or is_species_scope columns");
        }
        datasetPresenter.addNameTaxonPair(new NameTaxonPair(name, taxonId));
      }
      if (datasetPresenter.getFoundInDb()) 
        datasetNamesFoundInDb.addAll(datasetNamesFoundLocal);
    } finally {
      if (rs != null)
        rs.close();
    }
  }

  Set<String> findDatasetNamesInDb() throws SQLException {
    Set<String> datasetNamesInDb = new HashSet<String>();
    String sql = "select name from apidb.dataset";
    Statement stmt = null;
    ResultSet rs = null;
    try {
      stmt = dbConnection.createStatement();
      rs = stmt.executeQuery(sql);
      while (rs.next()) {
        datasetNamesInDb.add(rs.getString(1));
      }
    } finally {
      if (rs != null)
        rs.close();
      if (stmt != null)
        stmt.close();
    }
    return datasetNamesInDb;
  }

  void schemaInstall() {
    System.err.println("Installing DatasetPresenter schema into instance "
        + instance + " schema " + login + " using suffix " + suffix);
    manageSchema(false);
    System.err.println("Install complete");
  }

  void schemaDropConstraints() {
    System.err.println("Dropping integrity constraints from DatasetPresenter tables (so TuningManager can easily delete them)");
    manageSchema(true);
    System.err.println("Drop complete");
  }

  void manageSchema(boolean dropConstraints) {
    String mode = dropConstraints ? "-dropConstraints" : "-create";
    String[] cmd = { "presenterCreateSchema", instance, suffix, propFileName,
        mode };
    Process process;
    try {
      process = Runtime.getRuntime().exec(cmd);
      process.waitFor();
      if (process.exitValue() != 0)
        throw new UserException(
            "Failed running command to create DatasetPresenter schema: "
                + System.lineSeparator() + "presenterCreateSchema " + instance
                + " " + suffix + " " + propFileName + " " + mode);
      process.destroy();
    } catch (IOException | InterruptedException ex) {
      throw new UnexpectedException(ex);
    }
  }

  void loadDatasetPresenterSet() {
    System.err.println("Loading DatasetPresenters into " + instance);
    try {
      PreparedStatement presenterStmt = getPresenterStmt();
      PreparedStatement contactStmt = getContactStmt();
      PreparedStatement publicationStmt = getPublicationStmt();
      PreparedStatement referenceStmt = getReferenceStmt();
      PreparedStatement linkStmt = getLinkStmt();
      PreparedStatement nameTaxonStmt = getNameTaxonStmt();

      Map<String, Map<String, String>> defaultDatasetInjectorClasses = DatasetPresenterParser.parseDefaultInjectorsFile(defaultInjectorsFileName);

      for (DatasetPresenter datasetPresenter : dps.getDatasetPresenters().values()) {

        datasetPresenter.setDefaultDatasetInjector(defaultDatasetInjectorClasses);

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

        for (NameTaxonPair pair : datasetPresenter.getNameTaxonPairs()) {
          loadNameTaxonPair(datasetPresenterId, pair, nameTaxonStmt);
        }

      }
      System.err.println("Loading done");
    } catch (SQLException e) {
      throw new UnexpectedException(e);
    } finally {
      try {
        if (dbConnection != null)
          dbConnection.close();
      } catch (SQLException e) {
        throw new UnexpectedException(e);
      }
    }
  }

  PreparedStatement getDatasetTableStmt() throws SQLException {
    String table = "ApiDB.Dataset";
    String sql = "SELECT name, taxon_id, type, subtype, is_species_scope "
        + "FROM " + table + " WHERE name like ?";
    return dbConnection.prepareStatement(sql);
  }

  PreparedStatement getPresenterStmt() throws SQLException {
    String table = config.getUsername() + ".DatasetPresenter" + suffix;
    String sql = "INSERT INTO "
        + table
        + " (dataset_presenter_id, name, dataset_name_pattern, display_name, short_display_name, short_attribution, summary, protocol, usage, description, caveat, acknowledgement, release_policy, display_category, type, subtype, is_species_scope)"
        + " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
    return dbConnection.prepareStatement(sql);
  }

  private void loadDatasetPresenter(int datasetPresenterId,
      DatasetPresenter datasetPresenter, PreparedStatement stmt)
      throws SQLException {
      int i = 1;
    stmt.setInt(i++, datasetPresenterId);

    stmt.setString(i++, datasetPresenter.getDatasetName());
    stmt.setString(i++, datasetPresenter.getDatasetNamePattern());
    stmt.setString(i++, datasetPresenter.getDatasetDisplayName());
    stmt.setString(i++, datasetPresenter.getDatasetShortDisplayName());
    stmt.setString(i++, datasetPresenter.getShortAttribution());
    stmt.setString(i++, datasetPresenter.getSummary());
    stmt.setString(i++, datasetPresenter.getProtocol());
    stmt.setString(i++, datasetPresenter.getUsage());
    stmt.setString(i++, datasetPresenter.getDatasetDescrip());
    stmt.setString(i++, datasetPresenter.getCaveat());
    stmt.setString(i++, datasetPresenter.getAcknowledgement());
    stmt.setString(i++, datasetPresenter.getReleasePolicy());
    stmt.setString(i++, datasetPresenter.getDisplayCategory());
    stmt.setString(i++, datasetPresenter.getType());

    String subtype = datasetPresenter.getSubtype() == null ? "" : datasetPresenter.getSubtype();
    boolean isSpeciesScope = datasetPresenter.getIsSpeciesScope() == null ? false : datasetPresenter.getIsSpeciesScope();

    stmt.setString(i++, subtype);
    stmt.setBoolean(i++, isSpeciesScope);
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

    try {
        stmt.execute();
    } catch (SQLException e) {
        System.out.println("*****Error Loading Publication*****");
        System.out.println(publication.toString());
        throw(e);
    }
    
  }

  PreparedStatement getNameTaxonStmt() throws SQLException {
    String table = config.getUsername() + ".DatasetNameTaxon" + suffix;
    String sql = "INSERT INTO " + table
        + " (dataset_taxon_id, dataset_presenter_id, name, taxon_id)"
        + " VALUES (" + table + "_sq.nextval, ?, ?, ?)";
    return dbConnection.prepareStatement(sql);
  }

  private void loadNameTaxonPair(int datasetPresenterId, NameTaxonPair pair,
      PreparedStatement stmt) throws SQLException {
    stmt.setInt(1, datasetPresenterId);
    stmt.setString(2, pair.getName());
    stmt.setInt(3, pair.getTaxonId());
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
    stmt.setString(4, ref.getTargetName().replace(":", ""));
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

    CliUtil.addOption(
        options,
        "defaultInjectorClassesFile",
        "a three column tab delimited file:  type, subtype, injectorClass.  Provides default injectorClasses for type/subtypes",
        false, true);

    CliUtil.addOption(options, "instance",
        "the name of the instance to write to", true, true);

    CliUtil.addOption(
        options,
        "suffix",
        "the suffix to append to all tables created (as is always done in tuning tables).  Required but ignored if using the -report option",
        true, true);

    CliUtil.addOption(options, "report",
        "the name of the instance to write to", false, false);

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
        + " -presentersDir presenters_dir -contactsXmlFile contacts_file -tuningPropsXmlFile propFile -instance instance_name -suffix suffix [-defaultInjectorClassesFile tab_file] [-report]";
    String cmdDescrip = "Read provided dataset presenter files and inject templates into the presentation layer.";
    CommandLine cmdLine = CliUtil.parseOptions(cmdlineSyntax, cmdDescrip,
        getUsageNotes(), options, args);

    return cmdLine;
  }

  public static DatasetPresenterSetLoader constructLoader(CommandLine cmdLine) {
    String presentersDir = cmdLine.getOptionValue("presentersDir");
    String contactsFile = cmdLine.getOptionValue("contactsXmlFile");
    String propFile = cmdLine.getOptionValue("tuningPropsXmlFile");
    String defaultInjectorsFile = cmdLine.getOptionValue("defaultInjectorClassesFile");
    String instance = cmdLine.getOptionValue("instance");
    String suffix = cmdLine.getOptionValue("suffix");

    System.err.println("Parsing and validating DatasetPresenters XML files found in directory "
        + presentersDir);
    DatasetPresenterSet datasetPresenterSet = DatasetPresenterSet.createFromPresentersDir(presentersDir);
    DatasetPresenterSetLoader dpsl = new DatasetPresenterSetLoader(propFile,
        contactsFile, defaultInjectorsFile, instance, suffix);
    dpsl.setDatasetPresenterSet(datasetPresenterSet);
    Set<String> namesFromDbNotFound = dpsl.syncPresenterSetWithDatasetTable();
    if (namesFromDbNotFound.size() != 0)
      throw new UserException(
          "The following Dataset names in ApiDB.Dataset are not mentioned or matched by the input DatasetPresenters:"
              + nl + setToString(namesFromDbNotFound));

    System.err.println("Validation complete");
    return dpsl;
  }

  private static String setToString(Set<String> set) {
    StringBuffer buf = new StringBuffer();
    for (String s : set)
      buf.append(s + nl);
    return buf.toString();
  }

  public static void main(String[] args) throws Exception {
    CommandLine cmdLine = getCmdLine(args);

    try {
      // does all validation of presenters against ApiDB.Dataset
      DatasetPresenterSetLoader dpsl = constructLoader(cmdLine);

      if (!cmdLine.hasOption("report")) {
        dpsl.schemaInstall();
        dpsl.loadDatasetPresenterSet();
        dpsl.schemaDropConstraints();
      }
    } catch (UserException ex) {
      System.err.println(nl + "Error: " + ex.getMessage() + nl);
      System.exit(1);
    }
  }
}
