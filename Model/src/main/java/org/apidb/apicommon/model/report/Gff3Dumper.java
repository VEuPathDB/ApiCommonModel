package org.apidb.apicommon.model.report;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

import javax.sql.DataSource;

import org.apache.log4j.Logger;
import org.gusdb.fgputil.db.SqlUtils;
import org.gusdb.fgputil.runtime.GusHome;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.WdkUserException;
import org.gusdb.wdk.model.answer.AnswerValue;
import org.gusdb.wdk.model.answer.factory.AnswerValueFactory;
import org.gusdb.wdk.model.answer.spec.AnswerSpec;
import org.gusdb.wdk.model.query.spec.QueryInstanceSpec;
import org.gusdb.wdk.model.query.spec.QueryInstanceSpecBuilder;
import org.gusdb.wdk.model.report.config.StandardConfig;
import org.gusdb.wdk.model.report.reporter.PagedAnswerReporter;
import org.gusdb.wdk.model.report.util.ReporterFactory;
import org.gusdb.wdk.model.user.StepContainer;
import org.gusdb.wdk.model.user.User;

/**
 * Used to generate GFF download files that we put on our download sites. It calls Gff3Reporter to generate
 * GFF3 format, and then put the output into files for download site.
 * 
 * @author xingao
 */
public class Gff3Dumper {

  private static final int PAGE_SIZE = 1000;

  private static final Logger logger = Logger.getLogger(Gff3Dumper.class);

  public static void main(String[] args) throws Exception {
    if (args.length != 4 && args.length != 6) {
      System.err.println("Invalid parameters.");
      printUsage();
      System.exit(-1);
    }
    Map<String, String> cmdArgs = new HashMap<String, String>();
    for (int i = 0; i < args.length - 1; i += 2) {
      cmdArgs.put(args[i].trim().toLowerCase(), args[i + 1].trim());
    }

    // get params and validate
    String projectId = cmdArgs.get("-model");
    String organismArg = cmdArgs.get("-organism");
    String baseDir = cmdArgs.get("-dir");

    if (baseDir == null || baseDir.length() == 0) {
      baseDir = ".";
    }

    if (projectId == null || organismArg == null) {
      System.err.println("Missing parameters.");
      Gff3Dumper.printUsage();
      System.exit(-1);
    }

    String[] organisms = organismArg.split(",");

    try (WdkModel wdkModel = WdkModel.construct(projectId, GusHome.getGusHome())) {
      new Gff3Dumper(wdkModel, organisms, baseDir).dump();
    }

    System.out.println("Finished.");
  }

  public static void printUsage() {
    System.out.println();
    System.out.println("Usage: gffDump -model <model_name> -organism " + "<organism_list> [-dir <base_dir>]");
    System.out.println();
    System.out.println("\t\t<model_name>:\tThe name of WDK supported model;");
    System.out.println("\t\t<organism_list>: a list of organism names, " + "delimited by a comma;");
    System.out.println("\t\t<base_dir>: Optional, the base directory for "
        + "the output files. If not specified, the current directory " + "will be used.");
    System.out.println();
  }

  private final WdkModel wdkModel;
  private final String[] organisms;
  private final String baseDir;

  public Gff3Dumper(WdkModel wdkModel, String[] organisms, String baseDir) {
    this.wdkModel = wdkModel;
    this.organisms = organisms;
    this.baseDir = baseDir;
  }


  public void dump() throws WdkUserException, WdkModelException, IOException, SQLException {

    // TEST
    logger.info("Initializing....");

    // load config
    Map<String, String> config = new LinkedHashMap<String, String>();
    config.put(StandardConfig.ATTACHMENT_TYPE, "text");
    config.put(PagedAnswerReporter.PROPERTY_PAGE_SIZE, Integer.toString(PAGE_SIZE));
    config.put(Gff3Reporter.FIELD_HAS_TRANSCRIPT, "true");
    config.put(Gff3Reporter.FIELD_HAS_PROTEIN, "true");

    // prepare the organism ps
    String sql = "SELECT DISTINCT o.name_for_filenames "
        + " FROM apidb.organism o, dots.NaSequence ns, dots.GeneFeature gf,"
        + "      webready.GeneAttributes ga " + " WHERE gf.na_sequence_id = ns.na_sequence_id"
        + "   AND ga.source_id = gf.source_id " + "   AND ns.taxon_id = o.taxon_id "
        + "   AND ga.project_id = ? AND ga.organism = ?";
    DataSource dataSource = wdkModel.getAppDb().getDataSource();
    PreparedStatement psOrganism = null;
    try {
      psOrganism = SqlUtils.getPreparedStatement(dataSource, sql);
      for (String organism : organisms) {
        dumpOrganism(psOrganism, organism.trim(), config);
      }
    }
    finally {
      SqlUtils.closeStatement(psOrganism);
    }
  }

  private void dumpOrganism(PreparedStatement psOrganism, String organism, Map<String, String> config) throws WdkUserException,
      WdkModelException, IOException, SQLException {
    long start = System.currentTimeMillis();

    // decide the path-file name
    logger.info("Preparing gff file....");

    // format the file name.
    // Instead of using version in file name, we now use CURRENT to represent
    // the version.
    // String prefix = wdkModel.getProjectId() + "-" + wdkModel.getVersion() +
    // "_";
    String prefix = wdkModel.getProjectId() + "-CURRENT_";
    String organismFile = getOrganismFileName(psOrganism, organism);
    String fileName = prefix + organismFile + ".gff";

    File gffFile = new File(baseDir, fileName);
    PrintWriter writer = new PrintWriter(new FileWriter(gffFile));

    // prepare reporters
    logger.info("Preparing reporters....");

    QueryInstanceSpecBuilder params = QueryInstanceSpec.builder();
    params.put("gff_organism", organism);

    User user = wdkModel.getSystemUser();

    AnswerValue sqlAnswer = AnswerValueFactory.makeAnswer(
        AnswerSpec.builder(wdkModel)
        .setQuestionFullName("SequenceDumpQuestions.SequenceDumpQuestion")
        .setQueryInstanceSpec(params)
        .buildRunnable(user, StepContainer.emptyContainer()));
    Gff3Reporter seqReport = (Gff3Reporter) ReporterFactory.getReporter(sqlAnswer, "gff3", config);

    AnswerValue geneAnswer = AnswerValueFactory.makeAnswer(
        AnswerSpec.builder(wdkModel)
        .setQuestionFullName("GeneDumpQuestions.GeneDumpQuestion")
        .setQueryInstanceSpec(params)
        .buildRunnable(user, StepContainer.emptyContainer()));

    config.put(Gff3Reporter.FIELD_HAS_PROTEIN, "yes");
    Gff3Reporter geneReport = (Gff3Reporter) ReporterFactory.getReporter(geneAnswer, "gff3Dump", config);

    seqReport.initialize();
    geneReport.initialize();

    // remove rows from the cache table
    String cacheTable = geneReport.getCacheTable();
    String idSql = geneAnswer.getIdSql();
    deleteRows(idSql, cacheTable);

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

      // commented out fasta sequence in gff3 - refs #21488
      // collect the protein sequences
      //logger.info("Collecting protein sequences....");
      //writer.println("##FASTA");
      //geneReport.writeSequences(writer);

      // collect the genomic sequences
      //logger.info("Collecting genomic sequences....");
      //seqReport.writeSequences(writer);
    }
    finally {
      seqReport.complete();
      geneReport.complete();
      writer.flush();
      writer.close();

    }
    long end = System.currentTimeMillis();
    System.out.println("GFF3 file saved at " + gffFile.getAbsolutePath() + ".");
    logger.info("Time spent " + ((end - start) / 1000.0) + " seconds.");
  }

  private void deleteRows(String idSql, String cacheTable) throws SQLException {
    String sql = "DELETE FROM " + cacheTable + " WHERE source_id IN " + "(SELECT source_ID FROM (" + idSql +
        "))";
    DataSource dataSource = wdkModel.getAppDb().getDataSource();
    SqlUtils.executeUpdate(dataSource, sql, "gff-dump-delete-rows");
  }

  private String getOrganismFileName(PreparedStatement psOrganism, String organism) throws WdkModelException, SQLException {
    psOrganism.setString(1, wdkModel.getProjectId());
    psOrganism.setString(2, organism);
    ResultSet resultSet = null;
    try {
      resultSet = psOrganism.executeQuery();
      if (!resultSet.next()) {
        throw new WdkModelException("The organism '" + organism + "' cannot be recognized.");
      }
      return resultSet.getString(1);
    }
    finally {
      SqlUtils.closeQuietly(resultSet);
    }
  }
}
