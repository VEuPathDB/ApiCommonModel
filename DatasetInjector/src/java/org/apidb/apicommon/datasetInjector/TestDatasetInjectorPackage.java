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

/**
 * JUnit tests for the datasetInjector package
 * 
 * @author steve
 * 
 */
public class TestDatasetInjectorPackage {

  private static final String nl = System.getProperty("line.separator");

  private static final String validPrelude = "name=rnaSeqCoverageTrack" + nl
      + "anchorFile=ApiCommonShared/Model/lib/gbr/${projectName}.conf" + nl
      + "prop=datasetName" + nl + "#a comment" + nl + nl
      + "prop=datasetDisplayName" + nl;

  private static final String validPreludeTrimmed = "name=rnaSeqCoverageTrack"
      + nl + "anchorFile=ApiCommonShared/Model/lib/gbr/${projectName}.conf"
      + nl + "prop=datasetName" + nl + "prop=datasetDisplayName" + nl;

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
    TemplatesFileParser.parsePrelude(validPreludeTrimmed, template, "dontcare");
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

    String[] answer = TemplatesFileParser.splitTemplateString(validPrelude
        + TemplatesFileParser.TEMPLATE_TEXT_START + nl + validTemplateText
        + TemplatesFileParser.TEMPLATE_TEXT_END + nl, "fakeFilePath");

    assertTrue(answer[0].equals(validPreludeTrimmed));
    assertTrue(answer[1].equals(validTemplateText));
  }

  @Test(expected = UserException.class)
  public void test_Template_splitTemplateString2() {
    TemplatesFileParser.splitTemplateString(validPrelude
        + TemplatesFileParser.TEMPLATE_TEXT_START + nl + validTemplateText
        + TemplatesFileParser.TEMPLATE_TEXT_END + nl + "JUNK" + nl,
        "fakeFilePath");
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

    // make template
    Template template = new Template("dontcare");
    template.setName("rnaSeqFoldChangeQuestion");
    Set<String> props = new HashSet<String>();
    props.add("datasetName");
    template.setProps(props);
    template.setTemplateText(validTemplateText);

    // make template instances
    Map<String, String> propValues1 = new HashMap<String, String>();
    propValues1.put("datasetName", "HAPPY");
    TemplateInstance templateInstance1 = new TemplateInstance(
        template.getName(), propValues1);

    Map<String, String> propValues2 = new HashMap<String, String>();
    propValues2.put("datasetName", "SAD");
    TemplateInstance templateInstance2 = new TemplateInstance(
        template.getName(), propValues2);

    List<TemplateInstance> templateInstances = new ArrayList<TemplateInstance>();
    templateInstances.add(templateInstance1);
    templateInstances.add(templateInstance2);

    // make target text
    String targetText = "line 1" + nl
        + "<!-- TEMPLATE_ANCHOR rnaSeqFoldChangeQuestion -->" + nl + "line 3"
        + nl;
    InputStream targetTextAsStream = new ByteArrayInputStream(
        targetText.getBytes());

    // inject instances into target
    String answer = template.injectInstancesIntoStream(templateInstances,
        targetTextAsStream);

    // format expected result
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
    TemplatesFileParser.parseTemplatesFile(templateSet, proj_home
        + "/ApiCommonShared/DatasetInjector/testData/testTemplates.dst");

    assertTrue(templateSet.getTemplateByName("template1") != null);
    assertTrue(templateSet.getTemplateByName("template2") != null);
    Template t1 = templateSet.getTemplateByName("template1");
    Template t2 = templateSet.getTemplateByName("template2");
    assertTrue(t1.getTemplateText().equals("12345" + nl + "67890" + nl));
    assertTrue(t2.getTemplateText().equals(
        "12345" + nl + "67890" + nl + "abcde" + nl));
    assertTrue(templateSet.getTemplateNamesByAnchorFileName("file1").contains(
        "template1"));
    assertTrue(templateSet.getTemplateNamesByAnchorFileName("file1").contains(
        "template2"));
  }

  @Test
  public void test_DatasetInjector_setClass() {
    DatasetInjectorConstructor di = new DatasetInjectorConstructor();
    String className = "org.apidb.apicommon.model.datasetInjector.TestInjector";
    di.setClassName(className);
    assertTrue(di.getDatasetInjector().getClass().getName().equals(className));
  }

  @Test
  public void test_DatasetInjector_inheritDatasetProps() {
    DatasetInjectorConstructor di = new DatasetInjectorConstructor();
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
    DatasetInjectorConstructor di1 = new DatasetInjectorConstructor();
    di1.setClassName("org.apidb.apicommon.model.datasetInjector.TestInjector");
    dp1.addDatasetInjector(di1);
    DatasetInjectorConstructor di2 = new DatasetInjectorConstructor();
    di2.setClassName("org.apidb.apicommon.model.datasetInjector.TestInjector");
    dp1.addDatasetInjector(di2);
    dps.addDatasetPresenter(dp1);

    DatasetPresenter dp2 = new DatasetPresenter();
    dp2.setDatasetName("sad");
    DatasetInjectorConstructor di3 = new DatasetInjectorConstructor();
    di3.setClassName("org.apidb.apicommon.model.datasetInjector.TestInjector");
    dp2.addDatasetInjector(di3);
    dps.addDatasetPresenter(dp2);

    // run "inject" to produce a set of template instances
    DatasetInjectorSet dis = new DatasetInjectorSet();
    dps.addToDatasetInjectorSet(dis);

    List<TemplateInstance> fakeTemplate1Instances = dis.getTemplateInstanceSet().getTemplateInstances(
        "fakeTemplate1");
    assertTrue(fakeTemplate1Instances.size() == 3);
    assertTrue(fakeTemplate1Instances.get(0).getPropValue("datasetName").equals(
        "happy"));
    assertTrue(fakeTemplate1Instances.get(1).getPropValue("datasetName").equals(
        "happy"));
    assertTrue(fakeTemplate1Instances.get(2).getPropValue("datasetName").equals(
        "sad"));

    List<TemplateInstance> fakeTemplate2Instances = dis.getTemplateInstanceSet().getTemplateInstances(
        "fakeTemplate2");
    assertTrue(fakeTemplate2Instances.size() == 3);
    assertTrue(fakeTemplate2Instances.get(0).getPropValue("datasetName").equals(
        "happy"));
    assertTrue(fakeTemplate2Instances.get(1).getPropValue("datasetName").equals(
        "happy"));
    assertTrue(fakeTemplate2Instances.get(2).getPropValue("datasetName").equals(
        "sad"));

  }

  @Test
  public void test_DatasetPresenterParser_parse() {
    DatasetPresenterParser dpp = new DatasetPresenterParser();
    String project_home = System.getenv("PROJECT_HOME");

    DatasetPresenterSet dps = dpp.parse(project_home
        + "/ApiCommonShared/DatasetInjector/testData/presenterSet1.xml");
    assertTrue(dps.getSize() == 2);
    DatasetPresenter dp1 = dps.getDatasetPresenters().get(0);
    DatasetPresenter dp2 = dps.getDatasetPresenters().get(1);
    assertTrue(dp1.getDatasetName().equals("Stunnenberg_RNA-Seq"));
    assertTrue(dp2.getDatasetName().equals("Very_Happy"));
    assertTrue(dp2.getPropValue("datasetDisplayName").equals("In good spirits"));
    assertTrue(dp2.getPropValue("datasetShortDisplayName").equals("good"));
    assertTrue(dp2.getPropValue("organismShortName").equals("H. Sap"));
    assertTrue(dp2.getPropValue("projectName").equals("PlasmoDB"));
    assertTrue(dp2.getPropValue("buildNumberIntroduced").equals("17"));
//    assertTrue(dp2.getPropValue("isSingleStrand").equals("true"));
    assertTrue(dp1.getDatasetInjectors().size() == 1);
    assertTrue(dp2.getDatasetInjectors().size() == 1);
    DatasetInjectorConstructor dic = dp2.getDatasetInjectors().get(0);
    assertTrue(dp2.getDatasetInjectors().get(0).getDatasetInjectorClassName().equals("org.apidb.apicommon.model.datasetInjector.TestInjector"));
  }

  @Test
  public void test_TemplatesInjector_processDatasetPresenterSet() {

    String project_home = System.getenv("PROJECT_HOME");
    String gus_home = System.getenv("GUS_HOME");
    String templatesFilePath = project_home
        + "/ApiCommonShared/DatasetInjector/testData/testTemplates.dst";

    DatasetPresenterParser dpp = new DatasetPresenterParser();
    DatasetPresenterSet dps = dpp.parse(project_home
        + "/ApiCommonShared/DatasetInjector/testData/presenterSet1.xml");
    TemplateSet templateSet = new TemplateSet();
    TemplatesFileParser.parseTemplatesFile(templateSet, templatesFilePath);
    
    TemplatesInjector templatesInjector = new TemplatesInjector(dps, templateSet);
    
    templatesInjector.processDatasetPresenterSet(templatesFilePath,
        project_home, gus_home);
  }

}
