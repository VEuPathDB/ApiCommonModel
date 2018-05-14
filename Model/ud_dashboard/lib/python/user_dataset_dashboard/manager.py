from irods.session import iRODSSession

from irods.models import Collection, DataObject
from irods.query import Query
from irods.column import Criterion, Between
import paths


class Manager:
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

    def get_coll(self, path):
        """
        Generic method to return a Collection object identified by the given path.  There is
        no guarantee that a collection exists there.
        :param path: path identifying the Collection object to be returned
        :return: Collection object represented by that path
        """
        if self.session.collections.exists(path):
            return self.session.collections.get(path)
        return None

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
        return []

    def get_dataobj_names(self, path):
        """
        Generic method to return the names of all data objects under the collection identified by the given
        collection path.  There is no guarantee that a collection is found by the path given.
        :param path: collection path under which the data objects of interest reside
        :return: list of the names of the data objects found or an empty list if none are found or the
        collection itself does not exist.
        """
        if self.session.collections.exists(path):
            return [data_object.name for data_object in self.session.collections.get(path).data_objects] or []
        return []

    def get_dataobj_data(self, path):
        """
        Generic method to retrieve a string representation of the content given by the data object as described by the
        given path.  There is no guarantee that a data object is found by the path given.
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

    def get_dataobj_names_by_query(self, criteria):
        """
        Generic method to retrieve the name of all data objects returned by a query using the given criteria.
        :param criteria: a list of Criterion objects
        :return: the names of data object satisfying those criteria
        """
        query = Query(self.session, DataObject.name)
        for criterion in criteria:
            query = query.filter(criterion)
        results = query.execute()
        return [row[DataObject.name] for row in results.rows]

    def get_dataobj_names_created_between(self, path, start_time, end_time):
        query = Query(self.session, DataObject.name)
        query = query.filter(Collection.name == path) \
            .filter(Between(DataObject.create_time, (start_time, end_time)))
        results = query.execute()
        return [row[DataObject.name] for row in results.rows]

    def get_event_dataobj_names_created_since(self, start_time):
        """
        Returns the names of all event data objects created since the given start time.
        :param start_time: datetime in sec
        :return: list of all event data object names satisfying the criteria
        """
        criteria = [Criterion("=", Collection.name, paths.EVENTS_PATH),
                    Criterion(">=", DataObject.create_time, start_time)]
        return self.get_dataobj_names_by_query(criteria)

    def get_flag_dataobj_names_by_user(self, user_id):
        """
        Returns the names of all flag data objects associated with the given user.
        :param user_id: wdk id of user to whom the flags pertain
        :return: list of all flag data object names satisfying the criteria.
        """
        criteria = [Criterion("=", Collection.name, paths.FLAGS_PATH),
                    Criterion('like', DataObject.name, '%_u' + user_id + '%')]
        return self.get_dataobj_names_by_query(criteria)

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