from __future__ import print_function
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
    FLAG_INDICATOR = {'dataset':'export','success_dataset':'successful export','failure_dataset': 'failed export'}

    def __init__(self, dashboard, name):
        self.dashboard = dashboard
        self.manager = self.dashboard.manager
        self.name = name
        self.parse_flag_name()

    def parse_flag_name(self):
        """
        Pulls apart the flag data object's name in order to extract the flag type, the user, the exported dataset
        create date and the pid.
        """
        matches = re.match(r'(.*)_u(.*)_t(.*)_p(.*).*', self.name, flags=0)
        self.type = matches.group(1)
        self.indicator = self.FLAG_INDICATOR.get(self.type)
        self.user = self.dashboard.find_user_by_id(matches.group(2))
        self.exported = matches.group(3)
        self.export_pid = matches.group(4).replace(".txt","")

    def get_flag_contents(self):
         path = paths.FLAG_DATA_OBJECT_TEMPLATE.format(self.name)
         self.content = self.manager.get_dataobj_data(path)

    @staticmethod
    def display_header(show_owner, show_message):
        owner = "Owner" if show_owner else ""
        msg = "Msg" if show_message else ""
        if show_owner:
            print("{0:19} {1:17} {2:6} {3:65} {4:40}".format("Export Date", "Indicates", "Pid", "Owner", msg))
        else:
            print("{0:19} {1:17} {2:6} {3:40}".format("Export Date", "Indicates", "Pid", msg))

    def display(self, show_owner_info, show_messages):
        print("{0:19} {1:17} {2:6}".format(
              datetime.datetime.fromtimestamp(int(self.exported)/1000).strftime('%Y-%m-%d %H:%M:%S'),
              self.indicator,
              self.export_pid), end='')
        if show_owner_info:
            print("{0:25} - {1:25} ({2:10})".format(self.user.full_name, self.user.email, self.user.id), end='')
        if show_messages:
            if self.type == "failure_dataset":
                print("%40s" % self.get_flag_contents(), end='')
        print()
