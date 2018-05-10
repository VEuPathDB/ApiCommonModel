from __future__ import print_function
import paths
from flag import Flag


class Workspace:

    def __init__(self, dashboard):
        self.dashboard = dashboard
        self.manager = dashboard.manager
        self.id = self.get_workspace_identity()
        self.quota = self.get_default_quota()


    def get_default_quota(self):
        """Return quota which is stored in units of Mb."""
        return self.manager.get_dataobj_data(paths.DEFAULT_QUOTA_DATA_OBJECT_PATH).strip()

    def get_workspace_identity(self):
        """
        Returns the metadata designator for the iRODS the software is currently attached to.  This id is
        used by Jenkins to insure that it accepts only calls from the iRODS system it is configured to
        handle.
        :return: iRODS id - how Jenkins knows iRODS
        """
        workspace_coll = self.manager.get_coll(paths.WORKSPACES_PATH)
        return workspace_coll.metadata.get_one(self.dashboard.IRODS_ID).value

    @staticmethod
    def display_user_dataset_header():
        print("{0:9} {1:25} {2:25} {3:15}".format("User Id","User Name","User Email","Dataset Id"))

    def display_inventory(self):
        """
        Prints a summary view of the workspace contents
        :return:
        """
        self.display_user_dataset_header()
        user_coll_names = self.manager.get_coll_names(paths.USERS_PATH)
        for user_coll_name in user_coll_names:
            user = self.dashboard.find_user_by_id(user_coll_name)
            print("{0:9} {1:25} {2:25} ".format(user.id, user.full_name, user.email), end='')
            datasets_coll_path = paths.USER_DATASETS_COLLECTION_TEMPLATE.format(user_coll_name)
            dataset_coll_names = self.manager.get_coll_names(datasets_coll_path)
            if dataset_coll_names:
                first = True
                for dataset_coll_name in dataset_coll_names:
                    if first:
                        print("{0:15}".format(dataset_coll_name))
                        first = False
                    else:
                        print("{0:9} {1:25} {2:25} {3:15}".format("","","",dataset_coll_name))
            else:
                print()
        print("\nLanding Zone Tarballs (anything there should be short-lived):")
        tarballs = []
        tarball_names = self.manager.get_dataobj_names(paths.LANDING_ZONE_PATH)
        for tarball_name in tarball_names:
            print("Tarball: " + tarball_name)


    def display_exports(self):
        print("\nExports:")
        Flag.display_header(True, False)
        flags = []
        flag_dataobj_names = self.manager.get_dataobj_names(paths.FLAGS_PATH)
        for flag_dataobj_name in flag_dataobj_names:
            flag = Flag(self.dashboard, flag_dataobj_name)
            flags.append(flag)
        flags.sort(key=lambda flag: flag.exported)
        for flag in flags:
            flag.display(True, False)


    def display(self):
        print("iRODS Workspace - id: {} - host: {}".format(self.id, self.dashboard.workspace_host))
        print("Default quota is {} Gb".format(self.quota))
        print("\nInventory:")
        self.display_inventory()
        self.display_exports()
