package org.apidb.apicommon.model.ssgcid;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.Iterator;

import org.gusdb.fgputil.db.platform.SupportedPlatform;
import org.gusdb.fgputil.db.pool.ConnectionPoolConfig;
import org.gusdb.fgputil.db.pool.DatabaseInstance;
import org.gusdb.fgputil.db.pool.SimpleDbConfig;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
// requires Jackson http://wiki.fasterxml.com/JacksonDownload
// javac -classpath jackson-core-2.1.4.jar:jackson-databind-2.1.4.jar:commons-lang3-3.1.jar NetClientGet.java 
// jackson annotations JsonAutoDetect is required at runtime
// java -classpath .:jackson-core-2.1.4.jar:jackson-databind-2.1.4.jar:jackson-annotations-2.1.4.jar:commons-lang3-3.1.jar NetClientGet

public class Ssgcid {
 
    public static void createTuningTable(Connection dbc, String suffix)
	throws SQLException {

	String createSql = new String
	    ("create table ssgcid" + suffix + "(\n"
	     + "target             varchar2(13),\n"
	     + "eupathdb           varchar2(32),\n"
	     + "status             varchar2(30),\n"
	     + "selection_criteria varchar2(81),\n"
	     + "has_clone          varchar2(5),\n"
	     + "has_protein        varchar2(5)\n"
	     + ")");
	Statement createStmt = dbc.createStatement();
	createStmt.executeUpdate(createSql.toString());
    }

    public static void main(String[] args) throws SQLException, IOException, JsonProcessingException, IOException {
 
	if (args.length != 1) {
	    System.err.println("usage: java Ssgcid <suffix>");
	    System.exit(1);
	}
	String suffix = args[0];

	String instance = "";
	String schema = "";
	String password = "";

	BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
	instance = in.readLine();
	schema = in.readLine();
	password = in.readLine();

	ConnectionPoolConfig config = SimpleDbConfig.create(
	    SupportedPlatform.ORACLE, "jdbc:oracle:oci:@" + instance, schema, password);
	Connection dbc = new DatabaseInstance(config).getDataSource().getConnection();

	createTuningTable(dbc, suffix);

	String insertSql = new String
	    ("insert into ssgcid" + suffix + " (target, eupathdb, status, selection_criteria, has_clone, has_protein)"
             + "values (?, ?, ?, ?, ?, ?)");
	PreparedStatement insertStatement = dbc.prepareStatement(insertSql.toString());


	// URL url = new URL("http://www.ssgcid.org/eupath/list_all?format=json");
	// ObjectMapper mapper = new ObjectMapper();
	// ArrayNode root = (ArrayNode) mapper.readTree(url);

	String filename = new String("/tmp/ssgcid" + suffix + ".json");
	// Runtime.getRuntime().exec("wget http://www.ssgcid.org/eupath/list_all?format=json --output-document " + filename);
	File file = new File(filename);
	ObjectMapper mapper = new ObjectMapper();
	ArrayNode root = (ArrayNode) mapper.readTree(file);

	Iterator<JsonNode> jsonNodeIterator = root.elements();
	while (jsonNodeIterator.hasNext()) {
	    JsonNode jsonNode = jsonNodeIterator.next();
	    //int identifier = jsonNode.get("pk").intValue();
	    JsonNode fieldsNode = jsonNode.get("fields");

	    insertStatement.setString(1, jsonNode.get("pk").textValue());
	    insertStatement.setString(2, fieldsNode.get("eupathdb").textValue());
	    insertStatement.setString(3, fieldsNode.get("status").textValue());
	    insertStatement.setString(4, fieldsNode.get("selection_criteria").textValue());
	    insertStatement.setString(5, fieldsNode.get("has_clone").booleanValue() ? "true" : "false");
	    insertStatement.setString(6, fieldsNode.get("has_protein").booleanValue() ? "true" : "false");
	    insertStatement.executeUpdate();
	}		
    }

}
