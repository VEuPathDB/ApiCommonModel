package org.apidb.apicommon.datasetInjector;

import static org.junit.Assert.assertTrue;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.gusdb.fgputil.xml.NamedValue;
import org.junit.Test;

public class TestDatasetInjectorSet {

  private static final String nl = System.getProperty("line.separator");

  private static final String validPrelude = "name=rnaSeqCoverageTrack" + nl
      + "anchorFile=ApiCommonShared/Model/lib/gbr/${projectName}.conf" + nl
      + "targetFile=lib/gbr/${projectName}.conf" + nl + "prop=datasetName" + nl
      + "#a comment" + nl + nl + "prop=datasetDisplayName" + nl;

  private static final String validPreludeTrimmed = "name=rnaSeqCoverageTrack"
      + nl + "anchorFile=ApiCommonShared/Model/lib/gbr/${projectName}.conf"
      + nl + "targetFile=lib/gbr/${projectName}.conf" + nl + "prop=datasetName"
      + nl + "prop=datasetDisplayName" + nl;

  private static final String validTemplateText = "[${datasetName}]" + nl
      + "feature      = NextGenSeq:${datasetName}" + nl;

  @Test
  public void testCmdLine() {
    String[] cmd = { "-t", "-presenterFiles", "happy.xml" };
    // CommandLine cl = DatasetInjectorSet.getCmdLine(cmd);
    // assertTrue(cl.getOptionValue("presenterFiles").equals("happy.xml"));
  }

  @Test
  public void test_Template_validateTemplateText() {
    Template template = new Template("dontcare");
    Set<String> props = new HashSet<String>();
    props.add("datasetName");
    template.setProps(props);
    template.setTemplateText(validTemplateText);
    template.validateTemplateText();
  }

  @Test(expected = UserException.class)
  public void test_Template_validateTemplateText2() {
    Template template = new Template("dontcare");
    Set<String> props = new HashSet<String>();
    template.setProps(props);
    template.setTemplateText(validTemplateText);
    template.validateTemplateText();
  }

  // test: parse of template prelude
  @Test
  public void test_Template_parsePrelude() throws IOException {
    Template template = new Template("dontcare");
    template.parsePrelude(validPreludeTrimmed);
    assertTrue(template.getName().equals("rnaSeqCoverageTrack"));
    assertTrue(template.getAnchorFileName().equals(
        "ApiCommonShared/Model/lib/gbr/${projectName}.conf"));
    assertTrue(template.getTargetFileName().equals(
        "lib/gbr/${projectName}.conf"));
    assertTrue(template.getProps().size() == 2);
    assertTrue(template.getProps().contains("datasetName"));
  }

  @Test
  public void test_Template_splitTemplateString() {

    String[] answer = Template.splitTemplateString(validPrelude
        + Template.TEMPLATE_TEXT_START + nl + validTemplateText
        + Template.TEMPLATE_TEXT_END + nl, "fakeFilePath");

    assertTrue(answer[0].equals(validPreludeTrimmed));
    assertTrue(answer[1].equals(validTemplateText));
  }

  @Test(expected = UserException.class)
  public void test_Template_splitTemplateString2() {
    Template.splitTemplateString(validPrelude + Template.TEMPLATE_TEXT_START
        + nl + validTemplateText + Template.TEMPLATE_TEXT_END + nl + "JUNK"
        + nl, "fakeFilePath");
  }

  @Test
  public void test_Template_injectTextIntoStream() {
    Template template = new Template("dontcare");
    template.setName("rnaSeqFoldChangeQuestion");
    String targetText = "line 1" + nl
        + "<!-- TEMPLATE_ANCHOR rnaSeqFoldChangeQuestion -->" + nl + "line 3"
        + nl;
    InputStream targetTextAsStream = new ByteArrayInputStream(
        targetText.getBytes());
    String answer = template.injectTextIntoStream("WOOHOO" + nl,
        targetTextAsStream);
    assertTrue(answer.equals("line 1" + nl
        + "<!-- TEMPLATE_ANCHOR rnaSeqFoldChangeQuestion -->" + nl + nl
        + "WOOHOO" + nl + nl + "line 3" + nl));
  }

  @Test
  public void test_Template_injectInstancesIntoStream() {
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
    List<Map<String, String>> propValuesSet = new ArrayList<Map<String, String>>();
    propValuesSet.add(propValues1);
    propValuesSet.add(propValues2);
    String targetText = "line 1" + nl
        + "<!-- TEMPLATE_ANCHOR rnaSeqFoldChangeQuestion -->" + nl + "line 3"
        + nl;
    InputStream targetTextAsStream = new ByteArrayInputStream(
        targetText.getBytes());
    String answer = template.injectInstancesIntoStream(propValuesSet,
        targetTextAsStream);
    String inj1 = "[HAPPY]" + nl + "feature      = NextGenSeq:HAPPY" + nl;
    String inj2 = "[SAD]" + nl + "feature      = NextGenSeq:SAD" + nl;
    String expected = "line 1" + nl
        + "<!-- TEMPLATE_ANCHOR rnaSeqFoldChangeQuestion -->" + nl + nl + inj1
        + nl + inj2 + nl + nl + "line 3" + nl;
    assertTrue(answer.equals(expected));
  }

  @Test
  public void test_TemplateSet_parseTemplatesFile() {
    String proj_home = System.getenv("PROJECT_HOME");
    TemplateSet templateSet = new TemplateSet();
    templateSet.parseTemplatesFile(proj_home
        + "/ApiCommonShared/DatasetInjector/testData/testTemplates.dst");

    assertTrue(templateSet.getTemplateByName("template1") != null);
    assertTrue(templateSet.getTemplateByName("template2") != null);
    Template t1 = templateSet.getTemplateByName("template1");
    Template t2 = templateSet.getTemplateByName("template2");
    assertTrue(t1.getTemplateText().equals("12345" + nl + "67890" + nl));
    assertTrue(t2.getTemplateText().equals(
        "12345" + nl + "67890" + nl + "abcde" + nl));
  }

  @Test
  public void test_DatasetInjector_setClass() {
    DatasetInjector di = new DatasetInjector();
    String className = "org.apidb.apicommon.model.datasetInjector.RnaSeqInjectorInstance";
    di.setClass(className);
    assertTrue(di.getDatasetInjectorInstance().getClass().getName().equals(
        className));
  }

  @Test
  public void test_DatasetInjector_inheritDatasetProps() {
    DatasetInjector di = new DatasetInjector();
    DatasetPresenter dp = new DatasetPresenter();
    di.addProp(new NamedValue("size", "too_small"));
    di.addProp(new NamedValue("color", "ugly"));
    dp.addProp(new NamedValue("weight", "negative"));
    di.inheritDatasetProps(dp);
    assertTrue(di.getPropValues().keySet().size() == 3);
  }

  @Test
  public void test_DatasetInjectorSet_getTemplateInstances() {

    // build model
    DatasetPresenterSet dps = new DatasetPresenterSet();

    DatasetPresenter dp1 = new DatasetPresenter();
    dp1.setDatasetName("happy");
    DatasetInjector di1 = new DatasetInjector();
    di1.setClass("org.apidb.apicommon.model.datasetInjector.TestInjectorInstance");
    dp1.addDatasetInjector(di1);
    DatasetInjector di2 = new DatasetInjector();
    di2.setClass("org.apidb.apicommon.model.datasetInjector.TestInjectorInstance");
    dp1.addDatasetInjector(di2);
    dps.addDatasetPresenter(dp1);

    DatasetPresenter dp2 = new DatasetPresenter();
    dp2.setDatasetName("sad");
    DatasetInjector di3 = new DatasetInjector();
    di3.setClass("org.apidb.apicommon.model.datasetInjector.TestInjectorInstance");
    dp2.addDatasetInjector(di3);
    dps.addDatasetPresenter(dp2);

    // run "inject" to produce a set of template instances
    DatasetInjectorSet dis = dps.getDatasetInjectorSet();

    List<Map<String, String>> fakeTemplate1Instances = dis.getTemplateInstances("fakeTemplate1");
    assertTrue(fakeTemplate1Instances.size() == 3);
    assertTrue(fakeTemplate1Instances.get(0).get("datasetName").equals("happy"));
    assertTrue(fakeTemplate1Instances.get(1).get("datasetName").equals("happy"));
    assertTrue(fakeTemplate1Instances.get(2).get("datasetName").equals("sad"));

    List<Map<String, String>> fakeTemplate2Instances = dis.getTemplateInstances("fakeTemplate2");
    assertTrue(fakeTemplate2Instances.size() == 3);
    assertTrue(fakeTemplate2Instances.get(0).get("datasetName").equals("happy"));
    assertTrue(fakeTemplate2Instances.get(1).get("datasetName").equals("happy"));
    assertTrue(fakeTemplate2Instances.get(2).get("datasetName").equals("sad"));

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
