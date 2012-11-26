package org.apidb.apicommon.datasetInjector;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.util.HashMap;
import java.util.Map;
import java.util.Scanner;
import java.util.regex.Matcher;

/**
 * Parse a tab-delimited file of contacts into Contacts.
 * The fields are:
 * 
 */
public class ContactsFileParser {
  static Map<String, Contact> parseContactsFile(String contactsFileName) {
    Map<String, Contact> contacts = new HashMap<String, Contact>();
    File contactFile = new File(contactsFileName);
    Scanner scanner = null;
    try {
      FileInputStream fileInputStream = new FileInputStream(contactFile);
      scanner = new Scanner(fileInputStream);
      while (scanner.hasNextLine()) {
        String line = scanner.nextLine();
        line.split("\t");
      }
    } catch (FileNotFoundException ex) {
      // TODO Auto-generated catch block
      ex.printStackTrace();
    } finally {
      if (scanner != null) scanner.close();
    }
    return contacts;
  }
}
