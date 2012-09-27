package org.apidb.apicommon.datasetInjector.test;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import org.apache.commons.cli.CommandLine;
import org.apidb.apicommon.datasetInjector.DatasetInjectorSet;
import org.apidb.apicommon.datasetInjector.DatasetPresenterProcessor;
import org.apidb.apicommon.datasetInjector.Template;
import org.apidb.apicommon.datasetInjector.UserException;
import org.junit.Test;

public class TestDatasetInjectorSet {

  private static final String nl = System.getProperty("line.separator");

  private static final String validPrelude = "name=rnaSeqCoverageTrack"
      + nl
      + "targetFile=ApiCommonWebsite/trunk/Site/conf/gbrowse.conf/${projectName}"
      + nl + "prop=datasetName" + nl + "#a comment" + nl + nl
      + "prop=datasetDisplayName" + nl;

  private static final String validPreludeTrimmed = "name=rnaSeqCoverageTrack"
      + nl
      + "targetFile=ApiCommonWebsite/trunk/Site/conf/gbrowse.conf/${projectName}"
      + nl + "prop=datasetName" + nl + "prop=datasetDisplayName" + nl;

  private static final String validTemplateText = "[${datasetName}]" + nl
      + "feature      = NextGenSeq:${datasetName}" + nl;

  public TestDatasetInjectorSet() {

  }

  @Test
  public void testCmdLine() {
    String[] cmd = { "-t", "-presenterFiles", "happy.xml" };
    // CommandLine cl = DatasetInjectorSet.getCmdLine(cmd);
    // assertTrue(cl.getOptionValue("presenterFiles").equals("happy.xml"));
  }

  @Test
  public void testTemplateTextValid() {
    Template template = new Template("dontcare");
    Set<String> props = new HashSet<String>();
    props.add("datasetName");
    template.setProps(props);
    template.setTemplateText(validTemplateText);
    template.validateTemplateText();
  }

  @Test(expected = UserException.class)
  public void testTemplateTextInvalid() {
    Template template = new Template("dontcare");
    Set<String> props = new HashSet<String>();
    template.setProps(props);
    template.setTemplateText(validTemplateText);
    template.validateTemplateText();
  }

  // test: parse of template prelude
  @Test
  public void testTemplateParsePrelude() throws IOException {
    Template template = new Template("dontcare");
    template.parsePrelude(validPreludeTrimmed);
    assertTrue(template.getName().equals("rnaSeqCoverageTrack"));
    assertTrue(template.getTemplateTargetFileName().equals(
        "ApiCommonWebsite/trunk/Site/conf/gbrowse.conf/${projectName}"));
    assertTrue(template.getProps().size() == 2);
    assertTrue(template.getProps().contains("datasetName"));
  }

  @Test
  public void testTemplateStringSplitterValid() {

    String[] answer = Template.splitTemplateString(validPrelude
        + Template.TEMPLATE_TEXT_START + nl + validTemplateText
        + Template.TEMPLATE_TEXT_END + nl, "fakeFilePath");
    String tmp = answer[0];

    assertTrue(answer[0].equals(validPreludeTrimmed));
    assertTrue(answer[1].equals(validTemplateText));
  }

  @Test(expected = UserException.class)
  public void testTemplateStringSplitterInvalid() {
    Template.splitTemplateString(validPrelude + Template.TEMPLATE_TEXT_START + nl
        + validTemplateText + Template.TEMPLATE_TEXT_END + nl + "JUNK" + nl, "fakeFilePath");
  }

  // test: parse of templates
  @Test
  public void testParseTemplatesFile() {
    String proj_home = System.getenv("PROJECT_HOME");
    Map<String, Template> templatesByName = Template.parseTemplatesFile(proj_home
        + "/ApiCommonShared/DatasetInjector/testData/testTemplates.dst");
    assertTrue(templatesByName.containsKey("template1"));
    assertTrue(templatesByName.containsKey("template2"));
    Template t1 = templatesByName.get("template1");
    Template t2 = templatesByName.get("template2");
    assertTrue(t1.getTemplateText().equals("12345" + nl + "67890" + nl));
    assertTrue(t2.getTemplateText().equals(
        "12345" + nl + "67890" + nl + "abcde" + nl));
  }
  
  @Test
  public void testInjectTextIntoStream() {
    Template template = new Template("dontcare");
    template.setName("rnaSeqFoldChangeQuestion");
    String targetText = "line 1" + nl + "<!– TEMPLATE_ANCHOR rnaSeqFoldChangeQuestion -->" + nl + "line 3" + nl;
    InputStream targetTextAsStream = new ByteArrayInputStream(targetText.getBytes());   
    String answer = template.injectTextIntoStream("WOOHOO" + nl, targetTextAsStream);
    assertTrue(answer.equals("line 1" + nl + "<!– TEMPLATE_ANCHOR rnaSeqFoldChangeQuestion -->" + nl + nl + "WOOHOO" + nl + nl +"line 3" + nl));
  }
  
  @Test
  public void testInjectInstancesIntoStream() {
    Template template = new Template("dontcare");
    template.setName("rnaSeqFoldChangeQuestion");
    Set<String> props = new HashSet<String>();
    props.add("datasetName");
    template.setProps(props);
    template.setTemplateText(validTemplateText);
    Map<String, String> propValues1 = new HashMap<String, String>();
    propValues1.put("datasetName", "HAPPY");
    Map<String, String> propValues2 = new HashMap<String, String>();
    propValues2.put("datasetName", "SAD");
    Set<Map<String, String>> propValuesSet = new HashSet<Map<String, String>>();
    propValuesSet.add(propValues1);
    propValuesSet.add(propValues2);
    String targetText = "line 1" + nl + "<!– TEMPLATE_ANCHOR rnaSeqFoldChangeQuestion -->" + nl + "line 3" + nl;
    InputStream targetTextAsStream = new ByteArrayInputStream(targetText.getBytes());   
    String answer = template.injectInstancesIntoStream(propValuesSet, targetTextAsStream);
    String inj1 = "[HAPPY]" + nl
        + "feature      = NextGenSeq:HAPPY" + nl;
    String inj2 = "[SAD]" + nl
        + "feature      = NextGenSeq:SAD" + nl;
    String expected = "line 1" + nl + "<!– TEMPLATE_ANCHOR rnaSeqFoldChangeQuestion -->" + nl + nl + inj1 + nl + inj2 + nl + nl + "line 3" + nl;
    assertTrue(answer.equals(expected));
 }

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
