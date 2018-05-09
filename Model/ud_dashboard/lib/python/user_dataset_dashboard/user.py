from __future__ import print_function
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

    def display(self):
        print("\nUser Data")
        print("{} ({}) - {}".format(self.full_name, self.email, self.id))

        print("\nUser Exports")
        self.generate_related_flags()
        if self.flags:
            for flag in self.flags:
                flag.display(False)
        else:
            print("No exports currently exist for this user.")

        print("\nOwned Datasets: ", end='')
        datasets = self.get_datasets()
        if datasets:
            total_size = reduce(lambda x, y: x + y, [dataset.size for dataset in datasets])
            print("\tTotal size: {} bytes".format(total_size))
            for dataset in datasets:
                dataset.short_display()
        else:
            print("No datasets currently exist for this user.")

        print("\nDatasets Shared With User:")
        external_datasets = self.get_external_datasets()
        if external_datasets:
            for result in self.get_external_datasets():
                (owner_id, dataset) = result.split(".")
                owner = self.dashboard.find_user_by_id(owner_id)
                print("Dataset id: {} owned by {} ({}) - {}".format(dataset, owner.full_name, owner.email, owner_id))
        else:
            print("No datasets are currently being shared with this user.")

        print("\n")
