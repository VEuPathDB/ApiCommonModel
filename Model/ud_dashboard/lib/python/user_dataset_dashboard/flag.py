from __future__ import print_function
import datetime
import re
import paths
from prettytable import PrettyTable


class Flag:
    """
    This object holds information about flags, which are maintained as data objects in a flags collection under the
    workspaces collection.  The flags are of two varieties.  Much or all of a flag's information is carried in the
    flag's data object name, which is formated as:

        <success | failure >_dataset_u<user id>_t<timestamp in millsec>_p<pid><.txt>

    Flags indicate the status of exports (currently from Galaxy).  A flag without a 'success' or 'failure' prefix is
    delivered by Galaxy and served as a trigger to irods PEP to begin processing a freshly exported dataset.  Such a
    flag has no content.  Flags with the 'success' or 'failure' prefix are posted by the irods PEP and indicate the
    outcome of that processing.  Flags prefixed with 'failure' will content a limited diagnostic message.
    """
    FLAG_INDICATOR = {'dataset': 'export',
                      'success_dataset': 'successful export',
                      'failure_dataset': 'failed export'}

    def __init__(self, dashboard, name):
        self.dashboard = dashboard
        self.manager = self.dashboard.manager
        self.name = name
        self.type, self.indicator, self.exporter, self.exported, self.export_pid = self.parse_flag_name()
        self.valid = True if self.type else False
        self.content = None

    def parse_flag_name(self):
        """
        Pulls apart the flag data object's name in order to extract the flag type, the user, the exported dataset
        create date and the pid.
        :return: tuple provided components of parsed data object name: flag type, indicator, exporter, exported time,
        and export pid
        """
        matches = re.match(r'(.*)_u(.*)_t(.*)_p(.*).*', self.name, flags=0)
        if matches:
            flag_type = matches.group(1)
            indicator = self.FLAG_INDICATOR.get(flag_type)
            exporter = self.dashboard.find_user_by_id(matches.group(2))
            exported = matches.group(3)
            export_pid = matches.group(4).replace(".txt", "")
            return flag_type, indicator, exporter, exported, export_pid
        else:
            return None, None, None, None, None

    def get_flag_contents(self):
        """
        A failure flag data object will contain a message that will hopefully help diagnose the failure.  Other flags
        have no content.
        """
        path = paths.FLAG_DATA_OBJECT_TEMPLATE.format(self.name)
        return self.manager.get_dataobj_data(path)


    @staticmethod
    def display(flags, show_exporter, show_message):
        """
        Class method that takes in a set of flags and displays them.  Optionally, the caller can suppress display
        of the exporter (e.g., would be redundant information in a user report).  Also optionally, the caller can
        suppress display of any failure messages (those involve reading data object contents which would probably
        needlessly slow a workspace report).  The absence of flags is noted with a message.
        :param flags: set of flag objects to display
        :param show_exporter: true if the exporter (user) should be displayed and false otherwise.
        :param show_message: true if any failure msg should be displayed and false otherwise.
        """
        print("\nEXPORT HISTORY:")
        if flags:
            msg = "Msg" if show_message else ""
            flag_table = PrettyTable(["Export Date", "Indicates", "Pid", "Exporter", msg]) if show_exporter\
                else PrettyTable(["Export Date", "Indicates", "Pid", msg])
            flag_table.align["Indicates"] = "l"
            flag_table.align["Pid"] = "r"
            for flag in flags:
                row = [datetime.datetime.fromtimestamp(int(flag.exported)/1000).strftime('%Y-%m-%d %H:%M:%S'),
                       flag.indicator,
                       flag.export_pid]
                if show_exporter:
                    flag_table.align["Exporter"] = "l"
                    row.append(flag.exporter.formatted_user())
                row.append(flag.get_flag_contents()) if show_message and flag.type == "failure_dataset" else row.append("")
                flag_table.add_row(row)
            print(flag_table)
        else:
            print("No exports were found for the given circumstances.")