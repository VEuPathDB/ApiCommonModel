from __future__ import print_function
from workspace import Workspace
from dataset import Dataset
from flag import Flag
from event import Event
import paths
import datetime
from prettytable import PrettyTable


class User:
    """
    This object holds information about an irods user, which is represented in irods as a user collection under the
    users collection under workspaces.
    """

    def __init__(self, dashboard, user_id, full_name, email):
        self.dashboard = dashboard
        self.manager = dashboard.manager
        self.id = user_id
        self.email = email
        self.full_name = full_name
        self.datasets = []
        self.events = []
        self.flags = []

    def formatted_user(self):
        """
        Convenience method to return user data formatted for display
        :return: formatted user string
        """
        return "{} ({}) - {}".format(self.full_name, self.email, self.id)

    def get_datasets(self):
        datasets_coll_path = paths.USER_DATASETS_COLLECTION_TEMPLATE.format(self.id)
        dataset_ids = self.manager.get_coll_names(datasets_coll_path)
        return [Dataset(dashboard=self.dashboard,
                        dataset_id=dataset_id, owner_id=self.id) for dataset_id in dataset_ids]

    def get_external_datasets(self):
        """
        Returns the names of all external data objects associated with this user.  These data objects are
        empty of content.  All the information is carried in the data object name, which indicates the share
        owner and the dataset being shared.
        :return: a list of names of the external dataset data objects
        """
        external_dataset_coll_path = paths.USER_EXTERNAL_DATASETS_COLLECTION_TEMPLATE.format(self.id)
        return self.manager.get_dataobj_names(external_dataset_coll_path)

    def generate_related_flags(self):
        """
        Generates a list of Flag objects, sorted by exported dataset create time, associated with this user.
        """
        flags = self.manager.get_flag_dataobj_names_by_user(self.id)
        self.flags = [Flag(self.dashboard, flag) for flag in flags]
        self.flags.sort(key=lambda item: item.exported)

    def generate_related_events(self):
        """
        Generates a list of Event objects, sorted by event create time, associated with this user.
        """
        event_names = self.manager.get_dataobj_names(paths.EVENTS_PATH)
        self.events = []
        for event_name in event_names:
            event = Event(event_name, self.manager.get_dataobj_data(paths.EVENTS_DATA_OBJECT_TEMPLATE.
                                                                    format(event_name)))
            if any(dataset.dataset_id == event.dataset_id for dataset in self.datasets):
                self.events.append(event)
        self.events.sort(key=lambda item: item.event_id)

    def display_properites(self):
        """
        Convenience method to handle a key : value display of user properties.  The iRODS system contains only user
        wdk ids.  Full names and email addresses are gleaned from the account db.
        """
        print("\nPROPERTIES")
        properties_table = PrettyTable(["Property", "Value"])
        properties_table.align = "l"
        properties_table.add_row(["User Info", self.formatted_user()])
        if self.datasets:
            total_size = reduce(lambda acc, value: acc + value, [dataset.size for dataset in self.datasets])/1E6
        else:
            total_size = 0
        properties_table.add_row(["Usage", str(total_size) + " Mb"])
        quota = float(Workspace(dashboard=self.dashboard).get_default_quota())
        properties_table.add_row(["% Quota Used", round(100 * total_size/quota, 1)])
        print(properties_table)

    def display_flags(self):
        """
        Convenience method to handle tabular display of flags set by this user.  Presently, flags only refer to
        Galaxy exports.  The absence of flags is noted with a message.  Note that a user may have an existence on
        the iRODS system without ever having exported to it.
        """
        self.generate_related_flags()
        Flag.display(self.flags, False, True)

    def display_events(self):
        """
        Convenience method to handle tabular display of events set by this user.  Since generating event data can be a
        lengthy process, event data is generated only when the user report is set to include it.
        """
        self.generate_related_events()
        Event.display(self.dashboard, self.events)

    def display_datasets(self):
        """
        Convenience method to handle tabular display of datasets owned by this user.  The absence of datasets is
        noted with a message.
        """
        print("\nOWNED DATASETS:")
        if self.datasets:
            datasets_table = PrettyTable(["Dataset Id", "Create Date", "Total Size (Mb)", "Dataset Name"])
            datasets_table.align["Dataset Id"] = "r"
            datasets_table.align["Total Size (Mb)"] = "r"
            datasets_table.align["Dataset Name"] = "l"
            for dataset in self.datasets:
                datasets_table.add_row([dataset.dataset_id,
                     datetime.datetime.fromtimestamp(int(dataset.created)/1000).strftime('%Y-%m-%d %H:%M:%S'),
                                              "{: .6f}".format(dataset.size/1E6), dataset.name])
            print(datasets_table)
        else:
            print("No datasets currently exist for this user.")

    def display_shares(self):
        """
        Convenience method to handle tabular display of datasets currently shared with this user.  The absence of
        shares is noted with a message.
        """
        print("\nSHARED DATASETS:")
        external_datasets = self.get_external_datasets()
        if external_datasets:
            shares_table = PrettyTable(["Dataset Id", "Owner"])
            shares_table.align["Dataset Id"] = "r"
            shares_table.align["Owner"] = "l"
            for result in self.get_external_datasets():
                (owner_id, dataset) = result.split(".")
                owner = self.dashboard.find_user_by_id(owner_id)
                shares_table.add_row([dataset, owner.formatted_user()])
            print(shares_table)
        else:
            print("No datasets are currently being shared with this user.")

    def display(self, show_events):
        """
        Provides a full featured report of an iRODS user.
        """
        print("\niRODS USER REPORT for {}".format(self.email))
        self.datasets = self.get_datasets()
        self.display_properites()
        self.display_flags()
        if show_events:
            self.display_events()
        self.display_datasets()
        self.display_shares()
        print("")