from __future__ import print_function
from workspace import Workspace
from dataset import Dataset
from flag import Flag
import paths

class User:
    """
    This object holds information about an irods user, which is represented in irods as a user collection under the
    users collection under workspaces.
    """

    def __init__(self, dashboard, id, full_name, email):
        self.dashboard = dashboard
        self.manager = dashboard.manager
        self.id = id
        self.email = email
        self.full_name = full_name

    def get_datasets(self):
        datasets_coll_path = paths.USER_DATASETS_COLLECTION_TEMPLATE.format(self.id)
        dataset_ids = self.manager.get_coll_names(datasets_coll_path)
        return [Dataset(dashboard = self.dashboard, dataset_id = dataset_id, owner_id = self.id) for dataset_id in dataset_ids]

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
        self.flags.sort(key = lambda flag: flag.exported)

    def display_properites(self):
        """
        Convenience method to handle a key : value display of user properties.  The iRODS system contains only user
        wdk ids.  Full names and email addresses are gleaned from the account db.
        """
        print("\nPROPERTIES")
        print("{} ({}) - {}".format(self.full_name, self.email, self.id))
        total_size = reduce(lambda x, y: x + y, [dataset.size for dataset in self.datasets])/1E6
        print("{0:15} {1:.6f} Mb".format("Usage", total_size))
        quota = float(Workspace(self.dashboard).get_default_quota())
        print("{0:15} {1}".format("% Quota Used", round(100 * total_size/quota, 1)))

    def display_flags(self):
        """
        Convenience method to handle tabular display of flags set by this user.  Presently, flags only refer to
        Galaxy exports.  The table appears but the absence of flags is noted with a message.  Note that a user
        may have an existence on the iRODS system without having used it at all.
        """
        print("\nEXPORTS")
        Flag.display_header(False, True)
        self.generate_related_flags()
        if self.flags:
            for flag in self.flags:
                flag.display(False, True)
        else:
            print("No exports currently exist for this user.")

    def display_datasets(self):
        """
        Convenience method to handle tabular display of datasets owned by this user.  The table always appears
        but the absence of datasets is noted with a message.
        """
        print("\nOWNED DATASETS:")
        if self.datasets:
            Dataset.display_header()
            for dataset in self.datasets:
                dataset.display_dataset()
        else:
            print("No datasets currently exist for this user.")

    def display_shares(self):
        """
        Convenience method to handle tabular display of datasets currently shared with this user.  The table
        always appears but the absence of shares is noted with a message.
        """
        print("\nSHARED DATASETS:")
        print("{0:15} {1}".format("Dataset Id", "Owner"))
        external_datasets = self.get_external_datasets()
        if external_datasets:
            for result in self.get_external_datasets():
                (owner_id, dataset) = result.split(".")
                owner = self.dashboard.find_user_by_id(owner_id)
                print("{0:15} {1} ({2}) - {3}".format(dataset, owner.full_name, owner.email, owner_id))
        else:
            print("No datasets are currently being shared with this user.")

    def display(self):
        """
        Provides a full featured report of an iRODS user.
        """
        self.datasets = self.get_datasets()
        self.display_properites()
        self.display_flags()
        self.display_datasets()
        self.display_shares()
        print("")