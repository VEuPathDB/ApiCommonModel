package org.apidb.apicommon.datasetInjector.test;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.io.IOException;
import java.util.Map;

import org.apache.commons.cli.CommandLine;
import org.apidb.apicommon.datasetInjector.DatasetInjectorSet;
import org.apidb.apicommon.datasetInjector.Template;
import org.apidb.apicommon.datasetInjector.UserException;
import org.junit.Test;

public class DatasetInjectorSetTest {

  private static final String nl = System.getProperty("line.separator");
  
  private static final String validPrelude = "name=rnaSeqCoverageTrack"
      + nl
      + "targetFile=ApiCommonWebsite/trunk/Site/conf/gbrowse.conf/${projectName}"
      + nl + "prop=datasetName" + nl + "#a comment" + nl + nl + "prop=datasetDisplayName" + nl;
  
  private static final String validPreludeTrimmed = "name=rnaSeqCoverageTrack"
      + nl
      + "targetFile=ApiCommonWebsite/trunk/Site/conf/gbrowse.conf/${projectName}"
      + nl + "prop=datasetName" + nl + "prop=datasetDisplayName" + nl;

  private static final String validBody = "[${datasetName}]" + nl + "feature      = NextGenSeq:${datasetName}" + nl;
  
  public DatasetInjectorSetTest() {

  }

  @Test
  public void testCmdLine() {
    String[] cmd = { "-t", "-presenterFiles", "happy.xml" };
//    CommandLine cl = DatasetInjectorSet.getCmdLine(cmd);
 //   assertTrue(cl.getOptionValue("presenterFiles").equals("happy.xml"));
  }

  // test: parse of template prelude
  @Test
  public void testTemplateParsePrelude() throws IOException { 
    Template template = new Template();
    Template.parsePrelude(validPreludeTrimmed, template, "lib/dst/testTemplates.dst");
    assertTrue(template.getName().equals("rnaSeqCoverageTrack"));
    assertTrue(template.getTemplateTargetFileName().equals("ApiCommonWebsite/trunk/Site/conf/gbrowse.conf/${projectName}"));
    assertTrue(template.getProps().size() == 2);
    assertTrue(template.getProps().contains("datasetName"));
  }

  @Test
  public void testTemplateStringSplitterValid() {

    String[] answer = Template.splitTemplateString(validPrelude + Template.TEMPLATE_TEXT_START + nl + validBody + Template.TEMPLATE_TEXT_END + nl, "fakeFilePath");
    String tmp = answer[0];
    
    assertTrue(answer[0].equals(validPreludeTrimmed));
    assertTrue(answer[1].equals(validBody));
  }
  
  @Test (expected= UserException.class)
  public void testTemplateStringSplitterInvalid() {
    String prelude = "name=rnaSeqCoverageTrack"
        + nl
        + "targetFile=ApiCommonWebsite/trunk/Site/conf/gbrowse.conf/${projectName}"
        + nl + "prop=datasetName" + nl + "prop=datasetDisplayName" + nl;
    String body = "[${datasetName}]" + nl + "feature      = NextGenSeq:${datasetName}" + nl;

   Template.splitTemplateString(prelude + Template.TEMPLATE_TEXT_START + nl + body + Template.TEMPLATE_TEXT_END + nl + "JUNK" + nl, "fakeFilePath");
  }
  
  /*
  // test: parse of templates
  @Test
  public void testTemplatesParse() throws IOException {
    Map<String, Template> templatesByName = DatasetInjectorSet.parseTemplatesFile("lib/dst/testTemplates.dst");
  }
  */

  // test: validation of valid input DP xml file

  // test: validation of invalid input DP xml file

  // test: parse of DP xml file with single <datasetPresenter> and
  // <datasetInjector>.
  // - confirm construction of DatasetInjector
  // - confirm setting of standard properties (acquired from <datasetPresenter>)

  // test: construct RnaSeqInjectorInstance

  // test: parse of xml file with two DatasetInjectorInstances -- confirm got
  // two DIIs

  // test: given a set of DIIs, call injectTemplates on each. check that the
  // correct set of TemplateInstances is added

  // test: for one TemplateInstance, inject into the target file
}
