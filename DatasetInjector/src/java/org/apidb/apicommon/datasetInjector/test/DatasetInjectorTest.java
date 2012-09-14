package org.apidb.apicommon.datasetInjector.test;


import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.apache.commons.cli.CommandLine;
import org.apidb.apicommon.datasetInjector.DatasetInjector;
import org.junit.Test;

public class DatasetInjectorTest {

  public DatasetInjectorTest() {
    
  }
  
  
  @Test
  public void testCmdLine() {
    String[] cmd = {"-t", "-presenterFiles", "happy.xml"};
    DatasetInjector di = new FakeDatasetInjector();
    CommandLine cl = di.getCmdLine(cmd);
    assertTrue(cl.getOptionValue("presenterFiles").equals("happy.xml"));
  }
}
