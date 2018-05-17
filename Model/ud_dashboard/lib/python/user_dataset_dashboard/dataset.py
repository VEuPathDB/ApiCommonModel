import datetime
import json
import sys
from prettytable import PrettyTable
import paths
from event import Event


class Dataset:
    """
    This is the central object of the irods system and is found as a collection under the user's workspace under the
    datasets subcollection.  The structure is as follows:
        <user_id>
            datasets
                <dataset_id>
                    dataset.json
                    meta.json
                    datafiles
                        <data file 1>
                        <data file 2>
                        ...
    """

    def __init__(self, **kwargs):
        """
        A dataset is discoverable by its owner and dataset ids as those combine to identify the path to the dataset
        collection.  So they are the minimum needed to create a Dataset object.  Doing a minimal creation since some
        dataset properties (e.g., related events) can take time to generate and may not always be required for display.
        :param dashboard:
        :param owner_id: wdk id of owner
        :param dataset_id: id of dataset represented by this object
        """
        self.dashboard = kwargs.get("dashboard")
        self.manager = self.dashboard.manager
        self.dataset_id = kwargs.get("dataset_id")
        self.owner_id = kwargs.get("owner_id", None)
        if not self.owner_id:
            self.owner_id = self.get_dataset_owner(self.dataset_id)
        self.owner = self.dashboard.find_user_by_id(self.owner_id)
        self.name, self.summary, self.description = self.parse_metadata_json()
        self.created, self.type, self.size, self.projects, self.dependencies, self.datafiles = self.parse_dataset_json()
        self.events = []
        self.shares = {}
        self.handle_status = {"handled": False, "completed": "pending"}
        self.db_owner = {"consistent": False, "user": None}
        self.install_status = {"installed": False, "name": ""}
        self.db_shares = []

    def get_dataset_owner(self, dataset_id):
        """
        The dataset id is not sufficient information to locate a dataset collection directly.  The path to the
        dataset collection is formed with both the owner id and the dataset id.  This method indirectly
        determines the id of the dataset owner.
        :param dataset_id the id of the dataset
        :return: wdk id of the dataset owner.  Otherwise the dataset does not exist and the proceedure is
        terminated with a message to that effect.
        """
        user_ids = self.manager.get_coll_names(paths.USERS_PATH)
        for user_id in user_ids:
            datasets_coll_path = paths.USER_DATASETS_COLLECTION_TEMPLATE.format(user_id)
            dataset_coll_names = self.manager.get_coll_names(datasets_coll_path)
            for dataset_coll_name in dataset_coll_names:
                if dataset_coll_name == dataset_id:
                    return user_id
        sys.exit("The dataset id given (i.e., {}) belongs to no current dataset."
                 "  It may have been deleted previously.".format(dataset_id))

    def parse_dataset_json(self):
        """
        Populates the dataset object with information gathered from the dataset's dataset.json data object (i.e.,
        projects, type, create date, total size, dependency information and datafile information.
        :return: tuplic containing dataset create date, type of dataset, total size, project list, dependency data, and
        data file information.
        """
        dataset_json_path = paths.USER_DATASET_DATASET_DATA_OBJECT_TEMPLATE.format(self.owner_id, self.dataset_id)
        dataset_json_data = self.manager.get_dataobj_data(dataset_json_path)
        dataset_json = json.loads(dataset_json_data)
        return dataset_json["created"], dataset_json["type"], dataset_json["size"], \
            dataset_json["projects"], dataset_json["dependencies"], dataset_json["dataFiles"]

    def parse_metadata_json(self):
        """
        Populates the dataset object with information gathered from the dataset's meta.json data object (i.e.,
        dataset name, summary and description).
        :return: tuple containing dataset name, summary and description
        """
        metadata_json_path = paths.USER_DATASET_METADATA_DATA_OBJECT_TEMPLATE.format(self.owner_id, self.dataset_id)
        metadata_json_data = self.manager.get_dataobj_data(metadata_json_path)
        metadata_json = json.loads(metadata_json_data)
        return metadata_json["name"], metadata_json["summary"], metadata_json["description"]

    def get_shares(self):
        """
        Find a list of users (wdk ids), if any, with whom the given dataset is shared.  The data objects within a
        dataset's sharedWith collection are devoid of content.  The share recipient's wdk id is the data object's
        name.
        """
        dataset_shared_with_coll = paths.USER_DATASET_SHARED_WITH_COLLECTION_TEMPLATE\
            .format(self.owner_id, self.dataset_id)
        recipient_ids = self.manager.get_dataobj_names(dataset_shared_with_coll)
        for recipient_id in recipient_ids:
            self.shares[recipient_id] =\
                {"recipient": self.dashboard.find_user_by_id(recipient_id),
                 "valid": str(self.is_share_valid(recipient_id))}

    def is_share_valid(self, recipient_id):
        """
        An iRODS share has two components.  The owner identifies the share recipients in a sharedWith collection under
        the collection for the dataset being shared and each of those recipients have an externalDataset collection
        under their user collection that identifies each dataset shared with them and the dataset's owner.  Both
        components need to be in place for a dataset to be properly shared.  This method confirms that a sharedWith
        recipient has a matching externalDatasets collection component.
        :param recipient_id: wdk id of the share recipient
        :return: True if the share exists in the recipient's externalDatasets collection and False otherwise
        """
        return self.manager.is_external_dataset_dataobj_present(self.owner_id, self.dataset_id, recipient_id)

    def generate_event_list(self):
        """
        Create a list of events containing event information for this dataset.  Since identifying which event data
        objects correspond to which dataset requires reading each event data object, we cut the search down by looking
        only at those data objects created at or following the time at which the user dataset was created.  Then we
        examine each returned and only retain those having a dataset_id matching that of this user dataset.  This could
        be done more efficiently if the dataset_id corresponding to an event was also kept as iRODS metadata.
        """
        # The user dataset created time is in millisec but iRODS handles timestamps in sec
        dataset_create_time = datetime.datetime.fromtimestamp(int(self.created) / 1000)
        event_dataobj_names = self.manager.get_event_dataobj_names_created_since(dataset_create_time)
        for event_dataobj_name in event_dataobj_names:
            event_path = paths.EVENTS_DATA_OBJECT_TEMPLATE.format(event_dataobj_name)
            event = Event(event_dataobj_name, self.manager.get_dataobj_data(event_path))
            if event.dataset_id == self.dataset_id:
                self.events.append(event)
        self.events.sort(key=lambda item: item.event_id)

    def check_dataset_handled(self):
        """
        Determines whether the dataset has been 'handled' in the given appdb database.  This is determined by
        looking through the datasets events for the install event.  If found, it is used as a database lookup.
        Handled datasets are identified in the dataset by their install event id and as such entry provides a
        completed date or a null if an error prevents completion.
        """
        filtered = list(filter(lambda item: item.event == 'install', self.events))
        if filtered:
            install_event_id = next(iter(filtered)).event_id
            result = self.dashboard.appdb.get_handled_status(install_event_id)
            # THe else case (no row returned) is handled by the default setting in __init__
            if result:
                self.handle_status["handled"] = True
                self.handle_status["completed"] = result[1]
        else:
            self.handle_status["completed"] = "no install event found"

    def check_ownership(self):
        """
        Obtains the dataset owner from the given apidb database and accesses its consistency against that of the
        iRODS system.  Consistency requires that the db version of the dataset owner and the iRODS version of the
        dataset owner match.  Note that this makes sense to check only if the dataset is installed in this app
        database.
        """
        result = self.dashboard.appdb.get_owner(self.dataset_id)
        # The else case (no row returned) is handled by the default setting in __init__
        if result:
            self.db_owner["consistent"] = str(result[0]) == self.owner_id
            if not self.db_owner["consistent"]:
                self.db_owner["user"] = self.dashboard.find_user_by_id(str(result[0]))

    def check_shares(self):
        """
        Obtains the dataset shares from the given appdb database and accesses their consistency against the
        iRODS system.  Consistency requires that the share owner (iRODS) is the dataset owner (DB) and that the
        share recipient (iRODS) is the share recipient (DB).  Note that the iRODS shares must be obtained first and
        that the check makes sense only if the dataset is installed in this app database.
        """
        results = self.dashboard.appdb.get_shares(self.dataset_id)
        # Not checking that all shares present in iRODS have matches in DB.  Only checking the reverse.
        for result in results:
            db_share = dict()
            # Make sure to convert ids to strings prior to making comparisons
            db_share["consistent"] = str(result[0]) == self.owner_id and self.shares.get(str(result[1]))
            db_share["recipient"] = self.dashboard.find_user_by_id(str(result[1]))
            self.db_shares.append(db_share)

    def check_dataset_installed(self):
        """
        Determines whether the dataset has been 'installed' in the given appdb database.  If so, the name of the
        dataset in the database (name at the time of installation) is provided.  Note that this is a potential
        synchronization error since if the name in the database is used in any meaningful way (e.g., as the
        name for a relevant question).
        """
        result = self.dashboard.appdb.get_installation_status(self.dataset_id)
        # The else case (no row returned) is handled by the default setting in __init__
        if result:
            self.install_status["installed"] = True
            self.install_status["name"] = result[1]

    def display_database_info(self):
        """
        Convenience method to handle a key : value display of database properties specific to this dataset.  Note
        that if a dataset is not 'handled' in the database, it is certainly not 'installed'.
        """
        print("\nDATABASE INFORMATION: " + self.dashboard.appdb_name)
        database_info_table = PrettyTable(["Property", "Value"])
        database_info_table.align = "l"
        self.check_dataset_handled()
        database_info_table.add_row(["Handled", str(self.handle_status["handled"])])
        database_info_table.add_row(["Handled Info", self.handle_status.get("completed", "error'd")])
        if self.handle_status["handled"]:
            self.check_dataset_installed()
            database_info_table.add_row(["Installed", str(self.install_status["installed"])])
            if self.install_status["installed"]:
                database_info_table.add_row(["Installed As", self.install_status["name"]])
                self.check_ownership()
                database_info_table.add_row(["Owner Consistent", self.db_owner["consistent"]])
                if not self.db_owner["consistent"]:
                    db_owner = self.db_owner["user"].formatted_user() if self.db_owner["user"] else None
                    database_info_table.add_row(["DB Owner", db_owner])
                self.check_shares()
                for ctr, db_share in enumerate(self.db_shares):
                    key = "Shares" if ctr == 0 else ""
                    consistent = "consistent" if db_share["consistent"] else "inconsistent"
                    database_info_table.add_row([key,
                                               consistent +
                                               " / shared with " + db_share["recipient"].formatted_user()])
        print(database_info_table)

    def display_properites(self):
        """
        Convenience method to handle a key : value display of dataset properties.  Note that changes to name, summary
        and description are possible whereas other properties are immutable.
        """
        print("\nPROPERTIES:")
        properties_table = PrettyTable(["Property", "Value"])
        properties_table.align = "l"
        properties_table.add_row(["Dataset Id", self.dataset_id])
        properties_table.add_row(["Name", self.name])
        properties_table.add_row(["Summary", self.summary])
        properties_table.add_row(["Description", self.description])
        properties_table.add_row(["Owner", self.owner.formatted_user()])
        properties_table.add_row(["Created",
                                   datetime.datetime.fromtimestamp(int(self.created) / 1000)
                                   .strftime('%Y-%m-%d %H:%M:%S')])
        properties_table.add_row(["Type", "{} (v{})".format(self.type["name"], self.type["version"])])
        properties_table.add_row(["Total Size", "{:.6f} Mb".format(self.size/1E6)])
        properties_table.add_row(["Projects", ",".join(self.projects)])
        print(properties_table)

    def display_dependencies(self):
        """
        Convenience method to handle tabular display of dataset dependencies.  The absence of dependencies is noted
        with a message.
        """
        print("\nDEPENDENCIES:")
        if self.dependencies:
            dependency_table = PrettyTable(["Name", "Version", "Identifier"])
            dependency_table.align = "l"
            for dependency in self.dependencies:
                dependency_table.add_row([dependency["resourceDisplayName"],
                                          dependency["resourceVersion"],
                                          dependency["resourceIdentifier"]])
            print(dependency_table)
        else:
            print("The dataset has no dependecies")

    def display_datafiles(self):
        """
        Convenience method to handle tabular display of dataset data files.  The table always appears and
        should be populated by at least one datafile if the dataset is valid.  Lack of any datafiles will
        likely result in a parsing error during an installation attempt.
        """
        print("\nDATA FILES:")
        if self.datafiles:
            datafiles_table = PrettyTable(["File Name", "File Size (Mb)"])
            datafiles_table.align["File Name"] = "l"
            datafiles_table.align["File Size (Mb)"] = "r"
            for datafile in self.datafiles:
                datafiles_table.add_row([datafile["name"], "{:.6f}".format(datafile["size"]/1E6)])
            print(datafiles_table)
        else:
            print("This dataset does not indicate any datafiles and as such is not a valid dataset.")

    def display_shares(self):
        """
        Convenience method to handle tabular display of current share information.  The absence of shares is noted
        with a message.
        """
        print("\nCURRENT SHARES:")
        if self.shares:
            shares_table = PrettyTable(["Recipient", "Validated"])
            shares_table.align["Recipient"] = "l"
            for recipient_id in self.shares.keys():
                row = [self.shares[recipient_id]['recipient'].formatted_user(), self.shares[recipient_id]['valid']]
                shares_table.add_row(row)
            print(shares_table)
        else:
            print("This dataset is not currently shared.")

    def display_events(self):
        """
        Convenience method to handle tabular display of events history.  At a minimum, one should see an install event.
        One will never see a delete event since the dataset would have been removed just prior to the creation of
        such an event.
        """
        self.generate_event_list()
        Event.display(self.dashboard, self.events)

    def display(self):
        """
        Provides a full featured report of a user dataset.  The Dataset object is fully populated only prior to display
        since some of those processes could be lengthy depending on system usage.
        """
        print("\nUSER DATASET REPORT for {}".format(self.dataset_id))
        self.get_shares()
        self.display_properites()
        self.display_dependencies()
        self.display_datafiles()
        self.display_shares()
        self.display_events()
        self.display_database_info()
        print("")
