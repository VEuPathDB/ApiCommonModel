import cx_Oracle


class Account:

    def __init__(self, dashboard):
        self.dashboard = dashboard


    def get_users_by_user_ids(self, user_ids):
        connection = cx_Oracle.connect(self.dashboard.account_db_connection_string)
        cursor = connection.cursor()
        querystring = """
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
        cursor.execute(querystring)
        results =  cursor.fetchall()
        cursor.close()
        return results



    def getUserInfo(self, user_id):
        connection = cx_Oracle.connect(self.dashboard.account_db_connection_string)
        cursor = connection.cursor()
        querystring = """
          SELECT first_name | | ' ' | | last_name | | ' (' | | email | | ')' AS user_info
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
          WHERE user_id = """ + user_id
        cursor.execute(querystring)
        user = cursor.fetchone()[0]
        print(user)