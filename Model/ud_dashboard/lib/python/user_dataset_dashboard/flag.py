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
        self.content = self.manager.get_dataobj_data(path)

    @staticmethod
    def display_header(show_exporter, show_message):
        """
        A tabular display of flags may optionally show or hide exporter information and flag content (i.e., diagnostic
        messages).  The header accommodates those options.
        :param show_exporter: True if the exporter information is to be displayed and False otherwise
        :param show_message:  True if any messages are to be displayed and False otherwise
        """
        msg = "Msg" if show_message else ""
        if show_exporter:
            print("{0:19} {1:17} {2:9} {3:65} {4:40}".format("Export Date", "Indicates", "Pid", "Exporter", msg))
        else:
            print("{0:19} {1:17} {2:9} {3:40}".format("Export Date", "Indicates", "Pid", msg))

    def display(self, show_exporter, show_messages):
        """
        Provides a display of the flag contained within this Flag object.  The display may optionally show or hide
        exporter information and flag content.
        :param show_exporter: True if the exporter information is to be displayed and False otherwise
        :param show_messages: True if any message are to be displayed and False otherwise
        """
        print("{0:19} {1:17} {2:9}".format(
              datetime.datetime.fromtimestamp(int(self.exported)/1000).strftime('%Y-%m-%d %H:%M:%S'),
              self.indicator,
              self.export_pid), end='')
        if show_exporter:
            print("{0:<65}".format(self.exporter.full_name + " (" + self.exporter.email + ") - " + self.exporter.id),
                  end='')
        if show_messages:
            if self.type == "failure_dataset":
                print("{0:40}".format(self.get_flag_contents()))
        print()
