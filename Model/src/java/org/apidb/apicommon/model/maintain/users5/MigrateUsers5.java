/**
 * 
 */
package org.apidb.apicommon.model.maintain.users5;

import java.io.FileReader;
import java.io.IOException;
import java.io.Reader;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Properties;

import org.apache.ibatis.session.ExecutorType;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.apache.ibatis.session.SqlSessionFactoryBuilder;
import org.apache.log4j.Logger;
import org.gusdb.fgputil.BaseCLI;
import org.gusdb.wdk.model.Utilities;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.config.ModelConfigUserDB;

/**
 * @author jerric
 * 
 */
public class MigrateUsers5 extends BaseCLI {

  public static final int UPDATE_PAGE = 200;

  public static final String ARG_STAGE = "stage";
  public static final String ARG_CUTOFF_DATE = "cutoffDate";

  private static final String STAGE_PRE_RELEASE = "pre-release";
  private static final String STAGE_RELEASE = "release";

  private static final String DATE_FORMAT = "yyyy/MM/dd";

  private static final String CONFIG_FILE = "/config/migrate-user-5.xml";

  private static final String PROP_DB_CONNECTION = "db.connection";
  private static final String PROP_DB_LOGIN = "db.login";
  private static final String PROP_DB_PASSWORD = "db.password";

  public static final MigrationTask[] PRE_RELEASE_TASKS = { new GuestCleanupTask(),
      new CommentsCleanupTask(), new Users5CleanupTask() };

  public static final MigrationTask[] RELEASE_TASKS = { new FungiUserTask(), new FungiPreferenceTask(),
      new FungiFavoriteTask(), new FungiBasketTask(), new FungiDatasetTask(), new FungiStepTask(),
      new FungiStepParamTask(), new FungiStrategyTask(), new Users5MigrateTask(), new CommentsMigrateTask(),
      new Users5StepParamsTask(), new Users5DatasetsTask() };

  private static final Logger LOG = Logger.getLogger(MigrateUsers5.class);

  public static void main(String[] args) throws Exception {
    String cmdName = System.getProperty("cmdName");
    MigrateUsers5 migrator = new MigrateUsers5(cmdName);
    try {
      migrator.invoke(args);
      LOG.info("Userlogins5 migration is done.");
      System.exit(0);
    }
    catch (Exception ex) {
      ex.printStackTrace();
      LOG.error("Userlogins5 migration failed.");
      System.exit(-1);
    }
  }

  /**
   * 
   */
  public MigrateUsers5(String command) {
    super((command != null) ? command : "apiMigrateUsers5",
        "Migrate fungi user from userlogins3, and eupath users from userlogins4, into new userlogins5.");
  }

  @Override
  protected void declareOptions() {
    addSingleValueOption(ARG_PROJECT_ID, true, null, "Required. Any project_id. Only one project is needed "
        + " to provide connection information to the apicomm, and the data for all the projects needed to "
        + " be fixed in the userlogins5 schema.");

    addSingleValueOption(ARG_STAGE, true, null, "Required. The stage of the process. The valid options are " +
        STAGE_PRE_RELEASE + ", " + STAGE_RELEASE + ".");

    addSingleValueOption(ARG_CUTOFF_DATE, false, null, "Optional. Any guest user created by this date " +
        "will be backed up, and removed from the live schema defined in  the model-config.xml. " +
        "The data should be in this format: " + DATE_FORMAT);
  }

  @Override
  protected void execute() throws Exception {
    String gusHome = System.getProperty(Utilities.SYSTEM_PROPERTY_GUS_HOME);
    String projectId = (String) getOptionValue(ARG_PROJECT_ID);
    String stage = (String) getOptionValue(ARG_STAGE);
    Date cutoffDate = getCutoffDate();

    // verify stage
    if (!stage.equals(STAGE_PRE_RELEASE) && !stage.equals(STAGE_RELEASE))
      throw new Exception("invalid " + ARG_STAGE + " argument: " + stage);

    LOG.info("Migrating user into new userlogins5 schema... cutoffDate = " + cutoffDate);

    WdkModel wdkModel = WdkModel.construct(projectId, gusHome);
    SqlSessionFactory sessionFactory = getSessionFactory(wdkModel);

    MigrationTask[] tasks = null;
    if (stage.equals(STAGE_PRE_RELEASE)) {
      tasks = PRE_RELEASE_TASKS;
    }
    else if (stage.equals(STAGE_RELEASE)) {
      tasks = RELEASE_TASKS;
    }
    for (int i = 0; i < tasks.length; i++) {
      long start = System.currentTimeMillis();
      MigrationTask task = tasks[i];
      String display = "Task " + (i + 1) + "/" + tasks.length + ": " + task.getDisplay();
      LOG.info("Executing " + display + "...");

      // set wdkModel if needed
      if (task instanceof ModelAware) {
        ((ModelAware) task).setModel(wdkModel);
      }
      // set cutoff date if needed
      if (task instanceof CutoffDateAware) {
        ((CutoffDateAware) task).setCutoffDate(cutoffDate);
      }

      // determine executorType
      ExecutorType executorType = task.isBatchEnabled() ? ExecutorType.BATCH : ExecutorType.REUSE;
      SqlSession session = sessionFactory.openSession(executorType);
      try {
        task.execute(session);
        if (!task.validate(session))
          throw new Exception(display + " validation failed.");

        session.commit();
        LOG.info(display + " finished successfully in " + ((System.currentTimeMillis() - start) / 1000D) +
            " seconds.");
      }
      catch (Exception ex) {
        session.rollback();
        LOG.error(display + " failed with error: " + ex.getMessage());
        throw ex;
      }
      finally {
        session.close();
      }
    }
  }

  private Date getCutoffDate() throws ParseException {
    String cutoffDate = (String) getOptionValue(ARG_CUTOFF_DATE);
    Date date;
    if (cutoffDate != null) {
      SimpleDateFormat format = new SimpleDateFormat(DATE_FORMAT);
      date = format.parse(cutoffDate);
    }
    else { // default cutoff date is 2 days ago from now
      Calendar calendar = Calendar.getInstance();
      calendar.add(Calendar.DAY_OF_MONTH, -2);
      date = calendar.getTime();
    }
    return date;
  }

  private SqlSessionFactory getSessionFactory(WdkModel wdkModel) throws IOException {
    // get system properties
    Properties properties = System.getProperties();

    // put in db connection info
    ModelConfigUserDB userDB = wdkModel.getModelConfig().getUserDB();
    properties.put(PROP_DB_CONNECTION, userDB.getConnectionUrl());
    properties.put(PROP_DB_LOGIN, userDB.getLogin());
    properties.put(PROP_DB_PASSWORD, userDB.getPassword());

    Reader configReader = new FileReader(wdkModel.getGusHome() + CONFIG_FILE);
    SqlSessionFactoryBuilder builder = new SqlSessionFactoryBuilder();
    SqlSessionFactory sessionFactory = builder.build(configReader, properties);
    configReader.close();

    return sessionFactory;
  }
}
