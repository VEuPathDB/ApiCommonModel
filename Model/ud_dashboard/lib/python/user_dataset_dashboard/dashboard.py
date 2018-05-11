import os
import json
from account import Account
from manager import Manager
from workspace import Workspace
from user import User
from dataset import Dataset
import paths
import sys

class Dashboard:
    """
    The Dashboard is the point of entry for this software.  It contains the configuration data for the iRODS system
    and databases and houses the reports that the software offers.
    """
    CONFIGURATION_PATH = "/../../../configuration/config.json"
    IRODS_ID = "irods_id"

    def __init__(self):
        """
        The dashbard sets up the configuration information an references both the account db via the Account object
        and iRODS workspace via the Workspace object.
        """
        dirname = os.path.dirname(__file__)
        with open(dirname + self.CONFIGURATION_PATH, "r+") as config_file:
            config_json = json.load(config_file)
            self.workspace_host = str(config_json["workspace"]["host"])
            self.workspace_port = config_json["workspace"]["port"]
            self.workspace_user = str(config_json["workspace"]["user"])
            self.workspace_password = str(config_json["workspace"]["password"])
            self.workspace_zone = str(config_json["workspace"]["zone"])
            self.account_db_connection_string = \
            str(config_json["account_db"]["user"]) + "/" + \
            str(config_json["account_db"]["password"]) + "@" + \
            str(config_json["account_db"]["name"])
        self.account = Account(self)
        self.manager = Manager(self)
        self.users = self.create_user_cache()

    def create_user_cache(self):
        """
        Populates a list of User objects to serve as a cache for the duration of the command.  THe wdk id of all users
        currently having a workspace in iRODS were applied to the account db to recover full name and email address
        information to populate the User object.  Future lookups are made against this cache rather than against
        the database.
        :return: list of User objects encompassing current iRODS users.
        """
        users = []
        user_ids = self.manager.get_coll_names(paths.USERS_PATH)
        results = self.account.get_users_by_user_ids(user_ids)
        for result in results:
            user = User(self, str(result[0]), str(result[1]), str(result[2]))
            users.append(user)
        return users

    def find_user_by_id(self, user_id):
        """
        Returns a User object having the given user id
        :param user_id: wdk id of user to look up
        :return: the User object if found.  Otherwise the procedure halts with an error message.
        """
        user = [user for user in self.users if user.id == user_id]
        return user[0] if user else sys.exit("No user can be found for user id %s" % user_id)

    def find_user_by_email(self, email):
        """
        Returns a User object having the given user email address
        :param email: email address of the user to look up
        :return: the User object if found.  Otherwise the procedure halts with an error message.
        """
        user = [user for user in self.users if user.email == email]
        return user[0] if user else sys.exit("No user can be found with the email %s" % email)

    def workspace_report(self, args):
        """
        Reports the relevant inforamtion for the iRODS workspace.  Export and event history can be limited by
        start and end dates.
        :param args: optional start and end dates
        """
        start_date = args.start_date
        end_date = args.end_date
        workspace = Workspace(dashboard = self, start_date = start_date, end_date = end_date)
        workspace.display()

    def user_report(self, args):
        """
        Reports the relevant information for a user as given by his/her wdk user email (logon)
        :param args: user email
        """
        user_email = args.user_email
        show_events = args.show_events
        user = self.find_user_by_email(user_email)
        user.display(show_events)

    def dataset_report(self, args):
        """
        Reports the relevant information for a user dataset as given by its dataset id
        :param args: dataset id provided
        """
        dataset = Dataset(dashboard = self, dataset_id = args.dataset_id)
        dataset.display()
