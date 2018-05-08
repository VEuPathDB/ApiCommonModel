from irods.session import iRODSSession

from flag import Flag
from irods.models import Collection, DataObject
from irods.query import Query
from irods.column import Criterion
import paths


class Workspace:
    """
    This object contains data that applies to the iRODS system in general.  More importantly, it houses the
    iRODS session, which is re-used for the duration of the command issued.  All the methods that apply that
    session to gather iRODS data are housed here.  Additionally, a number of global strings which represent
    paths in the user dataset iRODS system are kept here.
    """


    def __init__(self, dashboard):
        """
        The workspace essentially contains the Dashboard object that creates it and an iRODS session.  The
        :param dashboard:
        """
        self.dashboard = dashboard
        self.session = self.get_irods_session()

    def get_irods_session(self):
        """
        Create one iRODS session and use it for the lenght of the command line command.
        :return: iRODS session
        """
        return iRODSSession(host=self.dashboard.workspace_host,
                            port=self.dashboard.workspace_port,
                            user=self.dashboard.workspace_user,
                            password=self.dashboard.workspace_password,
                            zone=self.dashboard.workspace_zone)

    def get_default_quota(self):
        """Return quota which is stored in units of Gb."""
        return self.get_dataobj_data(paths.DEFAULT_QUOTA_DATA_OBJECT_PATH)

    def get_coll_names(self, path):
        """
        Generic method to return the names of all collections under the collection identified by the
        given collection path.  There is no guarantee that a collection is found by the path given.
        :param path: collection path under which the collections of interest reside
        :return: list of the name of the collections found or an empty list if none are found or the
        collection itself does not exist.
        """
        if self.session.collections.exists(path):
            coll = self.session.collections.get(path)
            return [coll.name for coll in coll.subcollections] or []
        else:
            return []

    def get_dataobj_names(self, path):
        """
        Generic method to return the names of all data objects under the collection identified by the given
        collection path.  There is no guarantee that a collection is found by the path given.
        :param path: collection path under which the data objects of interest reside
        :return: list of the names of the data objects found or an empty list if none are found or the
        collection itself does not exist.
        """
        if(self.session.collections.exists(path)):
            return [data_object.name for data_object in self.session.collections.get(path).data_objects] or []
        else:
            return []

    def get_dataobj_data(self, path):
        """
        Retrieve a string representation of the content given by the data object as described by the given path.
        THere is no guarantee that a data object is found by the path given.
        :param path: path to the data object to be read
        :return: a string representation of the content of the data object and an empty string in the case of
        an empty data object or no data object.
        """
        data = ""
        if self.session.data_objects.exists(path):
            dataobj = self.session.data_objects.get(path)
            with dataobj.open('r+') as file:
                for line in file:
                    data += line
        return data

    def is_external_dataset_dataobj_present(self, owner_id, dataset_id, recipient_id):
        """
        Determines whether a share of a given user dataset by the given owner to the given recipient is manifest in
        the recipient's external dataset collection.
        :param owner_id: owner's WDK id
        :param dataset_id: irods dataset id
        :param recipient_id: recipient's WDK id
        :return: True if the share is manifest in the recipient's external dataset collection and False otherwise
        """
        user_external_dataset_coll = paths.USER_EXTERNAL_DATASETS_COLLECTION_TEMPLATE.format(recipient_id)
        if self.session.collections.exists(user_external_dataset_coll):
            query = Query(self.session, DataObject.name)\
                .filter(Collection.name == user_external_dataset_coll)\
                .filter(DataObject.name == owner_id + "." + dataset_id)\
                .count(DataObject.name)
            # Note that, due to replication, the count is likely to be 2 rather than 1
            return True if query.execute().rows[0][DataObject.name] > 0 else False
        else:
            return False

    def find_event_dataobj_names_created_since(self, start_time):
        """
        Returns the names of all event data objects created since the given start time
        :param start_time: datetime in sec
        :return: list of all event data object names satisfying the criteria
        """
        query = Query(self.session, DataObject.name).filter(Collection.name == paths.EVENTS_PATH).filter(
            DataObject.create_time >= start_time)
        results = query.execute()
        return [row[DataObject.name] for row in results.rows]

    def find_flag_dataobjs(self, user_id):
        """
        Find all flag data objects associated with the given user and use them to populate a
        list of Flag objects to be returned.  In the case of no flags, return an empty list.
        :param user_id: wdk id of user to whom the flags pertain
        :return: list of pertainent flags or an empty list.
        """
        related = Criterion('like', DataObject.name, '%_u' + user_id + '%')
        query = Query(self.session, DataObject.name)\
            .filter(Collection.name == paths.FLAGS_PATH)\
            .filter(related)
        results = query.execute()
        return [Flag(self.dashboard, row[DataObject.name]) for row in results.rows]

    def display_all_dataset_colls(self):
        users_collection = self.session.collections.get(paths.USERS_PATH)
        for user_coll in users_collection.subcollections:
            print("Datasets for user id: {}".format(user_coll.name))
            datasets_coll_path = paths.USER_DATASETS_COLLECTION_TEMPLATE.format(user_coll.name)
            dataset_coll_names = self.get_coll_names(datasets_coll_path)
            if dataset_coll_names:
                for dataset_coll_name in dataset_coll_names:
                    print("\tDataset id: {}".format(dataset_coll_name))
