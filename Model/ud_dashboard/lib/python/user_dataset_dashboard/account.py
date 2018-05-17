from oracle import Oracle

class Account:
    """
    Houses queries to the Eupath account db.
    """

    def __init__(self, connection_string):
        """
        Oracle underlies the account db
        :param connection_string: account db connection string
        """
        self.db = Oracle(connection_string)

    def get_users_by_user_ids(self, user_ids):
        """
        Query to obtain user information (full name and email) for a  given list of user wdk ids.
        :param user_ids: list of user wdk ids
        :return: id, full name and email data for each user
        """
        # TODO: Becomes inefficient with too many users.  Will need a better strategy.  Also can't use
        # bind variables with an IN clause.
        self.db.connect()
        sql = """
                   SELECT user_id, first_name | | ' ' | | last_name AS full_name, email
                   FROM (
                     SELECT
                       a.user_id, first_name, last_name, email
                     FROM userAccounts.accounts a
                     LEFT JOIN (
                       SELECT
                         user_id,
                         MAX(CASE WHEN key = 'first_name' THEN value END) AS first_name,
                         MAX(CASE WHEN key = 'last_name' THEN value END) AS last_name
                       FROM UserAccounts.Account_Properties
                       GROUP BY user_id) ap
                       ON a.user_id = ap.user_id
                     )
                   WHERE user_id IN (""" + ",".join(user_ids) + ")"
        try:
            self.db.execute(sql)
            results = self.db.cursor.fetchall()
            return results
        finally:
            self.db.disconnect()
