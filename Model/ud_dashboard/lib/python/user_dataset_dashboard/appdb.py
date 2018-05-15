from oracle import Oracle

class AppDB:
    """
    Houses queries to the Eupath app db.
    """

    def __init__(self, connection_string):
        """
        Oracle underlies the app db
        :param connection_string: app db connection string
        """
        self.db = Oracle(connection_string)

    def get_installation_status(self, dataset_id):
        """
        An installed dataset will appear in the installeduserdataset table.
        :param dataset_id: the id of the dataset to check for installation.
        :return: one or no results
        """
        self.db.connect()
        sql = """
              SELECT * FROM apidbuserdatasets.installeduserdataset WHERE user_dataset_id = :dataset_id
              """
        bindvars = {"dataset_id": dataset_id}
        try:
            self.db.execute(sql, bindvars)
            result = self.db.cursor.fetchone()
            return result
        finally:
            self.db.disconnect()

    def get_handled_status(self, event_id):
        """
        A handled dataset's install event will appear in the userdatasetevent table.  The presence of a date for
        the completed column indicates whether a user dataset was successfully handled or not.  An unsuccessfully
        handled datasets halts queue processing until cleared.  A successfully handled dataset may still not be
        installed.
        :param event_id: the dataset's install event id against which to lookup whether the dataset was handled.
        :return: one or no results
        """
        self.db.connect()
        sql = """
              SELECT * FROM apidbuserdatasets.userdatasetevent WHERE event_id = :event_id
              """
        bindvars = {"event_id": event_id}
        try:
            self.db.execute(sql, bindvars)
            result = self.db.cursor.fetchone()
            return result
        finally:
            self.db.disconnect()

    def get_owner(self, dataset_id):
        """
        A handled dataset's owner as found in the database should match the owner as determined via the dataset's
        dataset.json file.  The owner is immutable.
        :param dataset_id: the id of the dataset for which the user is checked
        :return: should be one row
        """
        self.db.connect()
        sql = """
              SELECT * FROM apidbuserdatasets.userdatasetowner WHERE user_dataset_id = :dataset_id
              """
        bindvars = {"dataset_id": dataset_id}
        try:
            self.db.execute(sql, bindvars)
            result = self.db.cursor.fetchone()
            return result
        finally:
            self.db.disconnect()

    def get_shares(self, dataset_id):
        sql = """
              SELECT * FROM apidbuserdatasets.userdatasetsharedwith WHERE user_dataset_id = :dataset_id
              """
        bindvars = {"dataset_id": dataset_id}
        try:
            self.db.execute(sql, bindvars)
            results = self.db.cursor.fetchall()
            return results
        finally:
            self.db.disconnect()

