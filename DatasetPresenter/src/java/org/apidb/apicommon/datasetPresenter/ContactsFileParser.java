package org.apidb.apicommon.datasetPresenter;

import java.io.File;
import java.io.IOException;
import java.net.URL;

import org.apache.commons.digester.Digester;
import org.gusdb.fgputil.xml.Text;
import org.gusdb.fgputil.xml.XmlParser;
import org.xml.sax.SAXException;

/**
 * Parse an XML representation of a DatasetPresenterSet into java objects. The
 * XML schema is described in lib/rng/datasetPresenter.rng.
 */
public class ContactsFileParser extends XmlParser {

  public ContactsFileParser() {
    // use the wrong .rng file. it is not worth it for now to make a right one
    super(System.getenv("GUS_HOME") + "/lib/rng/contacts.rng", false);
  }

  @Override
  protected Digester configureDigester() {
    Digester digester = new Digester();
    digester.setValidating(false);

    digester.addObjectCreate("contacts", Contacts.class);

    configureNode(digester, "contacts/contact", Contact.class, "addContact");

    configureNode(digester, "contacts/contact/name", Text.class, "setName");
    digester.addCallMethod("contacts/contact/name", "setText", 0);

    configureNode(digester, "contacts/contact/contactId", Text.class,
        "setContactId");
    digester.addCallMethod("contacts/contact/contactId", "setText", 0);

    configureNode(digester, "contacts/contact/email", Text.class, "setEmail");
    digester.addCallMethod("contacts/contact/email", "setText", 0);

    configureNode(digester, "contacts/contact/institution", Text.class,
        "setInstitution");
    digester.addCallMethod("contacts/contact/institution", "setText", 0);

    configureNode(digester, "contacts/contact/address", Text.class,
        "setAddress");
    digester.addCallMethod("contacts/contact/address", "setText", 0);

    configureNode(digester, "contacts/contact/city", Text.class, "setCity");
    digester.addCallMethod("contacts/contact/city", "setText", 0);

    configureNode(digester, "contacts/contact/state", Text.class, "setState");
    digester.addCallMethod("contacts/contact/state", "setText", 0);

    configureNode(digester, "contacts/contact/zip", Text.class, "setZip");
    digester.addCallMethod("contacts/contact/zip", "setText", 0);

    configureNode(digester, "contacts/contact/country", Text.class,
        "setCountry");
    digester.addCallMethod("contacts/contact/country", "setText", 0);

    return digester;
  }

  Contacts parseFile(String xmlFileName) {

    Contacts contacts = null;
    try {
      configure();
      validateXmlFile(xmlFileName);
      contacts = (Contacts) digester.parse(new File(xmlFileName));
      contacts.setContactsFileName(xmlFileName);
    } catch (IOException | SAXException ex) {
      throw new UnexpectedException(ex);
    }
    return contacts;
  }
  
  void validateXmlFile(String xmlFileName) {
    try {
      configure();
      File xmlFile = new File(xmlFileName);
      URL url = xmlFile.toURI().toURL();
      if (!validate(url)) {
        throw new UserException("Invalid XML file " + xmlFileName);
      }
    } catch (IOException | SAXException ex) {
      throw new UnexpectedException(ex);
    }
  }


}
