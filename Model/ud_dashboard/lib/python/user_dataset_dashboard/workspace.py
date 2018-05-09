import paths

class Workspace:

    def __init__(self, dashboard):
        self.dashboard = dashboard
        self.manager = dashboard.manager
        self.id = self.get_workspace_identity()
        self.quota = self.get_default_quota()


    def get_default_quota(self):
        """Return quota which is stored in units of Gb."""
        return self.manager.get_dataobj_data(paths.DEFAULT_QUOTA_DATA_OBJECT_PATH)

    def get_workspace_identity(self):
        """
        Returns the metadata designator for the iRODS the software is currently attached to.  This id is
        used by Jenkins to insure that it accepts only calls from the iRODS system it is configured to
        handle.
        :return: iRODS id - how Jenkins knows iRODS
        """
        workspace_coll = self.manager.get_coll(paths.WORKSPACES_PATH)
        return workspace_coll.metadata.get_one(self.dashboard.IRODS_ID).value

    def display_inventory(self):
        user_coll_names = self.manager.get_coll_names(paths.USERS_PATH)
        for user_coll_name in user_coll_names:
            user = self.dashboard.find_user_by_id(user_coll_name)
            print("Datasets for user: {} - {} ({})".format(user.full_name, user.email, user.id))
            datasets_coll_path = paths.USER_DATASETS_COLLECTION_TEMPLATE.format(user_coll_name)
            dataset_coll_names = self.manager.get_coll_names(datasets_coll_path)
            if dataset_coll_names:
                for dataset_coll_name in dataset_coll_names:
                    print("\tDataset id: {}".format(dataset_coll_name))


    def display(self):
        print("iRODS Workspace - id: {}".format(self.id))
        print("Default quota is {} Gb".format(self.quota))
        print("\nInventory:")
        self.display_inventory()
