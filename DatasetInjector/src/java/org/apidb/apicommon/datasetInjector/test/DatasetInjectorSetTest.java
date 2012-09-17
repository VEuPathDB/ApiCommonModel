package org.apidb.apicommon.datasetInjector.test;


import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.apache.commons.cli.CommandLine;
import org.apidb.apicommon.datasetInjector.DatasetInjectorSet;
import org.junit.Test;

public class DatasetInjectorSetTest {

  public DatasetInjectorSetTest() {
    
  }
  
  
  @Test
  public void testCmdLine() {
    String[] cmd = {"-t", "-presenterFiles", "happy.xml"};
    CommandLine cl = DatasetInjectorSet.getCmdLine(cmd);
    assertTrue(cl.getOptionValue("presenterFiles").equals("happy.xml"));
  }

  // test: parse of templates
  
  // test: validation of valid input DP xml file
  
  // test: validation of invalid input DP xml file
 
  // test: parse of DP xml file with single <datasetPresenter> and <datasetInjector>.  
  //   - confirm construction of DatasetInjector
  //   - confirm setting of standard properties (acquired from <datasetPresenter>)

  // test: construct RnaSeqInjectorInstance
  
  // test: parse of xml file with two DatasetInjectorInstances -- confirm got two DIIs
  
  // test: given a set of DIIs, call injectTemplates on each.  check that the correct set of TemplateInstances is added
   
  // test: for one TemplateInstance, inject into the target file
}

