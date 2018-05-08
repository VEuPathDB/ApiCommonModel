import datetime
import re
import paths


class Flag:
    """
    This object holds information about flags, which are maintained as data objects in a flags collection under the
    workspaces collection.  The flags are of two varieties.  Much or all of a flag's information is carried in the
    flag's data object name, which is formated as:

        <success | failure >_dataset_u<user id>_t<timestamp in millsec>_p<pid><.txt>

    Flags indicate the status of exports (currently from Galaxy).  A flag without a 'success' or 'failure' prefix is
    delivered by Galaxy and served as a trigger to irods PEP to begin processing a freshly exported dataset.  Such a
    flag has no content.  Flags with the 'success' or 'failure' prefix are posted by the irods PEP and indicate the outcome
    of that processing.  Flags prefixed with 'failure' will content a limited diagnostic message.
    """

    def __init__(self, dashboard, name):
        self.dashboard = dashboard
        self.workspace = dashboard.workspace
        self.name = name
        self.parse_flag_name()

    def parse_flag_name(self):
        """
        Pulls apart the flag data object's name in order to extract the flag type, the user, the exported dataset
        create date and the pid.
        """
        matches = re.match(r'(.*)_u(.*)_t(.*)_p(.*).*', self.name, flags=0)
        self.type = matches.group(1)
        self.user = self.dashboard.find_user_by_id(matches.group(2))
        self.exported = matches.group(3)
        self.export_pid = matches.group(4).replace(".txt","")

    def get_flag_contents(self):
         path = paths.FLAG_DATA_OBJECT_TEMPLATE.format(self.name)
         self.content = self.workspace.get_dataobj_data(path)

    def display(self, show_owner_info):
        print("Export:  Date: {}, Type: {}, Export Pid: {}".
              format(datetime.datetime.fromtimestamp(int(self.exported)/1000).strftime('%Y-%m-%d %H:%M:%S'),
                     self.type,
                     self.export_pid))
        if show_owner_info:
            print("Owner: {} ({}) - {}".format(self.user.full_name, self.user.email, self.user.id))
        if self.type == "failure_dataset":
            print("\tMessage: {}".format(self.get_flag_contents()))





