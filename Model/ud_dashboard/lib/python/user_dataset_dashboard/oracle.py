import cx_Oracle
import sys

class Oracle():
    """
    Extracts connect, execute and disconnect operations to encapsulate Oracle specifics and error handling.
    """

    def __init__(self, connection_string):
        """
        Connection uses provided connection string
        :param connection_string:
        """
        self.connection_string = connection_string
        self.connection = None
        self.cursor = None

    def connect(self):
        """
        This object instance will create and hold references to the connection and cursor objects.  Presumably, no finally
        needed by the calling function since the connection will not have been made if an error is raised here.
        """
        try:
            self.connection = cx_Oracle.connect(self.connection_string)
        except cx_Oracle.DatabaseError as e:
            sys.stderr.write("Unable to connect to the account database: {}".format(e))
            raise
        self.cursor = self.connection.cursor()

    def disconnect(self):
        """
        This will close cursor and connection objects for this object instance and should be applied in a finally
        clause by the calling function.
        """
        try:
            self.cursor.close()
            self.connection.close()
        except cx_Oracle.DatabaseError as e:
            pass

    def execute(self, sql, bindvars=None):
        """
        Exexutes the provided sql using the provided bind variables (in dictionary form).  Note that, as this dashboard
        is meant to be read only, there is no need for any commit.
        :param sql:
        :param bindvars:
        """
        try:
            if bindvars:
                self.cursor.execute(sql, bindvars)
            else:
                self.cursor.execute(sql)
        except cx_Oracle.DatabaseError as e:
            sys.stderr.write("Unable to execute the query {}".format(e))
            raise