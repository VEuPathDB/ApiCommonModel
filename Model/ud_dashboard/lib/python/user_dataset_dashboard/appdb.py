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
