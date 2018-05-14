import cx_Oracle
import sys

class Oracle():

    def __init__(self, connection_string):
        self.connection_string = connection_string
        self.connection = None
        self.cursor = None

    def connect(self):
        try:
            self.connection = cx_Oracle.connect(self.connection_string)
        except cx_Oracle.DatabaseError as e:
            sys.stderr.write("Unable to connect to the account database: {}".format(e))
            raise
        self.cursor = self.connection.cursor()

    def disconnect(self):
        try:
            self.cursor.close()
            self.connection.close()
            print("Disconnected")
        except cx_Oracle.DatabaseError as e:
            pass

    def execute(self, sql, bindvars=None):
        print(bindvars)
        try:
            if bindvars:
                self.cursor.execute(sql, bindvars)
            else:
                self.cursor.execute(sql)
        except cx_Oracle.DatabaseError as e:
            sys.stderr.write("Unable to execute the query {}".format(e))
            raise