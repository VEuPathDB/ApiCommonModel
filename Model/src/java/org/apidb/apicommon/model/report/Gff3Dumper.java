/**
 * 
 */
package org.apidb.apicommon.model.report;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.security.NoSuchAlgorithmException;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

import javax.sql.DataSource;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactoryConfigurationError;

import org.apache.log4j.Logger;
import org.gusdb.wdk.model.Utilities;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.WdkUserException;
import org.gusdb.wdk.model.answer.AnswerValue;
import org.gusdb.wdk.model.dbms.SqlUtils;
import org.gusdb.wdk.model.question.Question;
import org.gusdb.wdk.model.report.Reporter;
import org.gusdb.wdk.model.user.User;
import org.json.JSONException;
import org.xml.sax.SAXException;

/**
 * @author xingao
 * 
 */
public class Gff3Dumper {

  private static final Logger logger = Logger.getLogger(Gff3Dumper.class);

  /**
   * @param args
   * @throws WdkModelException
   * @throws WdkUserException
   * @throws IOException
   * @throws ClassNotFoundException
   * @throws IllegalAccessException
   * @throws InstantiationException
   * @throws JSONException
   * @throws SQLException
   * @throws SAXException
   * @throws TransformerException
   * @throws TransformerFactoryConfigurationError
   * @throws ParserConfigurationException
   * @throws NoSuchAlgorithmException
   */
  public static void main(String[] args) throws WdkModelException,
      WdkUserException, IOException, NoSuchAlgorithmException,
      ParserConfigurationException, TransformerFactoryConfigurationError,
      TransformerException, SAXException, SQLException, JSONException,
      InstantiationException, IllegalAccessException, ClassNotFoundException {
    if (args.length != 4 && args.length != 6) {
      System.err.println("Invalid parameters.");
      printUsage();
      System.exit(-1);
    }
    Map<String, String> cmdArgs = new HashMap<String, String>();
    for (int i = 0; i < args.length - 1; i += 2) {
      cmdArgs.put(args[i].trim().toLowerCase(), args[i + 1].trim());
    }

    Gff3Dumper dumper = new Gff3Dumper(cmdArgs);
    dumper.dump();

    System.out.println("Finished.");
  }

  public static void printUsage() {
    System.out.println();
    System.out.println("Usage: gffDump -model <model_name> -organism "
        + "<organism_list> [-dir <base_dir>]");
    System.out.println();
    System.out.println("\t\t<model_name>:\tThe name of WDK supported model;");
    System.out.println("\t\t<organism_list>: a list of organism names, "
        + "delimited by a comma;");
    System.out.println("\t\t<base_dir>: Optional, the base directory for "
        + "the output files. If not specified, the current directory "
        + "will be used.");
    System.out.println();
  }

  private String baseDir;
  private WdkModel wdkModel;
  private String[] organisms;

  private PreparedStatement psOrganism;

  public Gff3Dumper(Map<String, String> cmdArgs) throws WdkModelException,
      NoSuchAlgorithmException, WdkUserException, ParserConfigurationException,
      TransformerFactoryConfigurationError, TransformerException, IOException,
      SAXException, SQLException, JSONException, InstantiationException,
      IllegalAccessException, ClassNotFoundException {
    // get params
    String modelName = cmdArgs.get("-model");
    String organismArg = cmdArgs.get("-organism");
    this.baseDir = cmdArgs.get("-dir");

    if (modelName == null || organismArg == null) {
      System.err.println("Missing parameters.");
      Gff3Dumper.printUsage();
      System.exit(-1);
    }
    if (baseDir == null || baseDir.length() == 0)
      baseDir = ".";

    // construct wdkModel
    String gusHome = System.getProperty(Utilities.SYSTEM_PROPERTY_GUS_HOME);
    this.wdkModel = WdkModel.construct(modelName, gusHome);

    this.organisms = organismArg.split(",");
  }

  public void dump() throws WdkUserException, WdkModelException,
      NoSuchAlgorithmException, IOException, SQLException, JSONException {

    // TEST
    logger.info("Initializing....");

    // load config
    Map<String, String> config = new LinkedHashMap<String, String>();
    config.put(Reporter.FIELD_FORMAT, "text");
    config.put(Gff3Reporter.FIELD_HAS_TRANSCRIPT, "true");
    config.put(Gff3Reporter.FIELD_HAS_PROTEIN, "true");

    // prepare the organism ps
    String sql = "SELECT DISTINCT o.name_for_filenames "
        + " FROM apidb.organism o, dots.NaSequence ns, dots.GeneFeature gf,"
        + "      ApidbTuning.geneattributes ga "
        + " WHERE gf.na_sequence_id = ns.na_sequence_id"
        + "   AND ga.source_id = gf.source_id "
        + "   AND ns.taxon_id = o.taxon_id "
        + "   AND ga.project_id = ? AND ga.organism = ?";
    DataSource dataSource = wdkModel.getQueryPlatform().getDataSource();
    psOrganism = SqlUtils.getPreparedStatement(dataSource, sql);

    try {
      for (String organism : organisms) {
        dumpOrganism(wdkModel, organism.trim(), config, baseDir);
      }
    } finally {
      SqlUtils.closeStatement(psOrganism);
    }
  }

  private void dumpOrganism(WdkModel wdkModel, String organism,
      Map<String, String> config, String baseDir) throws WdkUserException,
      WdkModelException, IOException, NoSuchAlgorithmException, SQLException,
      JSONException {
    long start = System.currentTimeMillis();

    // decide the path-file name
    logger.info("Preparing gff file....");

    // format the file name.
    // Instead of using version in file name, we now use CURRENT to represent
    // the version.
    // String prefix = wdkModel.getProjectId() + "-" + wdkModel.getVersion() +
    // "_";
    String prefix = wdkModel.getProjectId() + "-CURRENT_";
    String organismFile = getOrganismFileName(organism);
    String fileName = prefix + organismFile + ".gff";

    File gffFile = new File(baseDir, fileName);
    PrintWriter writer = new PrintWriter(new FileWriter(gffFile));

    // prepare reporters
    logger.info("Preparing reporters....");

    Map<String, String> params = new LinkedHashMap<String, String>();
    params.put("gff_organism", organism);

    User user = wdkModel.getSystemUser();
    Question seqQuestion = (Question) wdkModel.resolveReference("SequenceDumpQuestions.SequenceDumpQuestion");
    AnswerValue sqlAnswer = seqQuestion.makeAnswerValue(user, params, true, 0);
    Gff3Reporter seqReport = (Gff3Reporter) sqlAnswer.createReport("gff3",
        config);

    Question geneQuestion = (Question) wdkModel.resolveReference("GeneDumpQuestions.GeneDumpQuestion");
    AnswerValue geneAnswer = geneQuestion.makeAnswerValue(user, params, true, 0);

    config.put(Gff3Reporter.FIELD_HAS_PROTEIN, "yes");
    Gff3Reporter geneReport = (Gff3Reporter) geneAnswer.createReport(
        "gff3Dump", config);

    seqReport.initialize();
    geneReport.initialize();

    // remove rows from the cache table
    String cacheTable = geneReport.getCacheTable();
    String idSql = geneAnswer.getIdSql();
    deleteRows(wdkModel, idSql, cacheTable);

    try {
      // collect the header from sequence reporter
      logger.info("Collecting header....");
      seqReport.writeHeader(writer);

      // collect the sequence records
      logger.info("Collecting sequence records....");
      seqReport.writeRecords(writer);

      // collect the gene records
      logger.info("Collecting gene records....");
      geneReport.writeRecords(writer);

      // collect the protein sequences
      logger.info("Collecting protein sequences....");
      writer.println("##FASTA");
      geneReport.writeSequences(writer);

      // collect the genomic sequences
      logger.info("Collecting genomic sequences....");
      seqReport.writeSequences(writer);
    } finally {
      seqReport.complete();
      geneReport.complete();
      writer.flush();
      writer.close();

    }
    long end = System.currentTimeMillis();
    System.out.println("GFF3 file saved at " + gffFile.getAbsolutePath() + ".");
    logger.info("Time spent " + ((end - start) / 1000.0) + " seconds.");
  }

  private void deleteRows(WdkModel wdkModel, String idSql, String cacheTable)
      throws WdkUserException, WdkModelException, SQLException {
    String sql = "DELETE FROM " + cacheTable + " WHERE source_id IN "
        + "(SELECT source_ID FROM (" + idSql + "))";
    DataSource dataSource = wdkModel.getQueryPlatform().getDataSource();
    SqlUtils.executeUpdate(wdkModel, dataSource, sql, "gff-dump-delete-rows");
  }

  private String getOrganismFileName(String organism) throws WdkModelException,
      SQLException {
    psOrganism.setString(1, wdkModel.getProjectId());
    psOrganism.setString(2, organism);
    ResultSet resultSet = psOrganism.executeQuery();
    if (!resultSet.next()) {
      throw new WdkModelException("The organism '" + organism
          + "' cannot be recognized.");
    }
    String fileName = resultSet.getString(1);
    resultSet.close();
    return fileName;
  }
}
