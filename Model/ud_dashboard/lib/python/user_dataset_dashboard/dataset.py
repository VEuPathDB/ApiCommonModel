import datetime
import json
import sys
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
        self.parse_metadata_json()
        self.parse_dataset_json()
        self.events = []
        self.shares = {}

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
        sys.exit("The dataset id given (i.e., %s) belongs to no current dataset.  It may have been deleted previously."
              % dataset_id)


    def parse_dataset_json(self):
        """
        Populates the dataset object with information gathered from the dataset's dataset.json data object (i.e.,
        projects, type, create date, total size, dependency information and datafile information.
        """
        dataset_json_path = paths.USER_DATASET_DATASET_DATA_OBJECT_TEMPLATE.format(self.owner_id, self.dataset_id)
        dataset_json_data = self.manager.get_dataobj_data(dataset_json_path)
        dataset_json = json.loads(dataset_json_data)
        self.projects = dataset_json["projects"]
        self.created = dataset_json["created"]
        self.type = dataset_json["type"]
        self.size = dataset_json["size"]
        self.projects = dataset_json["projects"]
        self.dependencies = dataset_json["dependencies"]
        self.datafiles = dataset_json["dataFiles"]

    def parse_metadata_json(self):
        """
        Populates the dataset object with information gathered from the dataset's meta.json data object (i.e.,
        dataset name, summary and description).
        :return:
        """
        metadata_json_path = paths.USER_DATASET_METADATA_DATA_OBJECT_TEMPLATE.format(self.owner_id, self.dataset_id)
        metadata_json_data = self.manager.get_dataobj_data(metadata_json_path)
        metadata_json = json.loads(metadata_json_data)
        self.name = metadata_json["name"]
        self.summary = metadata_json["summary"]
        self.description = metadata_json["description"]

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
            self.shares[recipient_id] = {"recipient" : self.dashboard.find_user_by_id(recipient_id), "valid" : self.is_share_valid(recipient_id)}

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
            event = Event(self.manager.get_dataobj_data(event_path))
            if event.dataset_id == self.dataset_id:
                self.events.append(event)
        self.events.sort(key = lambda x: x.event_id)

    def short_display(self):
        """
        Provides a more abbreviated report of a user dataset based upon content available in the meta.json and
        dataset.json objects only.
        """
        print("\nDataset: {} - ({})".format(self.name, self.dataset_id))
        print("Created {}"
              .format(datetime.datetime.fromtimestamp(int(self.created) / 1000).strftime('%Y-%m-%d %H:%M:%S')))
        print("Total Size {} bytes".format(self.size))

    def display_properites(self):
        format_string = "{0:15} {1:70}"
        print("\nPROPERTIES:")
        print(format_string.format("Property","Value"))
        print(format_string.format("Dataset Id", self.dataset_id))
        print(format_string.format("Name", self.name))
        print(format_string.format("Summary", self.summary))
        print(format_string.format("Description", self.description))
        print("{0:15} {1} ({2}) - {3}".format("Owner", self.owner.full_name, self.owner.email, self.owner_id))
        print(format_string.format("Created",
                                   datetime.datetime.fromtimestamp(int(self.created) / 1000).strftime('%Y-%m-%d %H:%M:%S')))
        print("{0:15} {1} (v{2})".format("Type", self.type["name"], self.type["version"]))
        print("{0:15} {1} Mb".format("Total Size", self.size/1E6))
        print(format_string.format("Projects",",".join(self.projects)))

    def display_dependencies(self):
        format_string = "{0:30} {1:10} {2:40}"
        print("\nDEPENDENCIES:")
        print(format_string.format("Name", "Version", "Identifier"))
        if self.dependencies:
            for dependency in self.dependencies:
                print(format_string.format(dependency["resourceDisplayName"],
                    dependency["resourceVersion"],
                    dependency["resourceIdentifier"]))
        else:
            print("The dataset has no dependecies")

    def display_datafiles(self):
        """
        Convenience method to handle tabular display of dataset data files.  The table always appears and
        should be populated by at least one datafile if the dataset is valid.  Lack of any datafiles will
        likely result in a parsing error during an installation attempt.
        """
        format_string = "{0:25} {1:14}"
        print("\nDATA FILES:")
        print(format_string.format("File Name","File Size (Mb)"))
        if self.datafiles:
            for datafile in self.datafiles:
                print(format_string.format(datafile["name"], datafile["size"]/1E6))
        else:
            print("This dataset does not indicate any datafiles and as such is not a valid dataset.")

    def display_shares(self):
        """
        Convenience method to handle tabular display of current share information.  The table always appears but
        an absence of shares is noted with a message.
        """
        format_string = "{0:25} {1:25} {2:15} {3:9}"
        print("\nCURRENT SHARES:")
        print(format_string.format("Recipient Name", "Recipient Email", "Recipient Id","Validated"))
        if self.shares:
            for recipient_id in self.shares.keys():
                print(format_string.
                    format(self.shares[recipient_id]['recipient'].full_name,
                    self.shares[recipient_id]['recipient'].email,
                    recipient_id,
                    self.shares[recipient_id]['valid']))
        else:
            print("This dataset is not currently shared.")

    def display_events(self):
        """
        Convenience method to handle tabular display of events history.  At a minimum, one should see an install event.
        One will never see a delete event since the dataset would have been removed just prior to the creation of
        such an event.
        """
        print("\nEVENT HISTORY:")
        Event.display_header()
        for event in self.events:
            event.display(self.dashboard)


    def display(self):
        """
        Provides a full featured report of a user dataset.  The Dataset object is fully populated only prior to display
        since some of those processes could be lengthy depending on system usage.
        """
        self.get_shares()
        self.generate_event_list()
        self.display_properites()
        self.display_dependencies()
        self.display_datafiles()
        self.display_shares()
        self.display_events()

