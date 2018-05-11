from __future__ import print_function
import re
import datetime
import paths
from flag import Flag
from event import Event


class Workspace:

    def __init__(self, **kwargs):
        """
        start_date and end_date parameters are set to encompass the lifetime of the iRODS workspace by default, but
        can be refined to a more limited period when the command for the report is issued.  This dates only affect
        the output of flag (exports) and event history.
        :param kwargs: dashboard, start_date and end_date parameters
        """
        self.dashboard = kwargs.get('dashboard')
        self.manager = self.dashboard.manager
        self.start_date = kwargs.get('start_date')
        self.end_date = kwargs.get('end_date')
        self.id = self.get_workspace_identity()
        self.quota = self.get_default_quota()
        self.flags = []
        self.events = []

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

    def generate_related_flags(self):
        """
        Generates a list of Flag objects, sorted by exported dataset create time, created during the period specified.
        If no period is specified, all flags are displayed.  If only a start date is specified, only those flags created
        between then and the current time are displayed.  If only an end date is specified, only those flags created
        up to but not including the end date are displayed.
        """
        flag_dataobj_names = self.manager\
            .get_dataobj_names_created_between(paths.FLAGS_PATH, self.start_date, self.end_date)
        self.flags = [Flag(self.dashboard, flag_dataobj_name) for flag_dataobj_name in flag_dataobj_names]
        self.flags.sort(key=lambda item: item.exported)

    def generate_related_events(self):
        """
        Generates a list of Event objects, sorted by event creation time, created during the periond specified.
        If no period is specified, all events are displayed.  If only a start date is specified, only those events
        created between then and the current time are displayed.  If only an end date is specified, only those events
        created up to but not including the end date are displayed.
        """
        event_dataobj_names = self.manager\
            .get_dataobj_names_created_between(paths.EVENTS_PATH, self.start_date, self.end_date)
        for event_dataobj_name in event_dataobj_names:
            event_path = paths.EVENTS_DATA_OBJECT_TEMPLATE.format(event_dataobj_name)
            event = Event(self.manager.get_dataobj_data(event_path))
            self.events.append(event)
        self.events.sort(key=lambda item: item.event_id)

    def parse_tarball_name(self, name):
        """
        Pulls apart the tarball data object's name in order to extract the the user, the export date and the export pid.
        These components should match up with at least two export flags.
        :return: tuple providing components of parsed data object name:  exporter, exported time, and export pid.  If
        the data object's name format is not observed, None is returned.
        """
        matches = re.match(r'dataset_u(.*)_t(.*)_p(.*).tgz', name, flags=0)
        if matches:
            exporter = self.dashboard.find_user_by_id(matches.group(1))
            return exporter, matches.group(2), matches.group(3)
        else:
            return None, None, None

    def display_inventory(self):
        """
        Prints a summary view of the workspace contents
        """
        print("\nINVENTORY:")
        print("{0:9} {1:25} {2:25} {3:15}".format("User Id", "User Name", "User Email", "Dataset Id"))
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
                        print("{0:9} {1:25} {2:25} {3:15}".format("", "", "", dataset_coll_name))
            else:
                print()

    def display_landing_zone_content(self):
        """
        Convenience method to handle tabular display of any residual tarballs in the landing zone.  Tarballs should
        have the name format: dataset__u<user id>_t<timestamp in millsec>_p<pid>.tgz.  Any items matching this
        format should have a corresponding pair of export flags in the flags collection.  Anything that does not
        match the naming convention is simply detritus.
        """
        print("\nLANDING ZONE (Note: Any tarballs there should be short-lived):")
        print("{0:45} {1:19} {2:6} {3}".format("Name", "Export Date", "Pid", "Exporter"))
        tarball_names = self.manager.get_dataobj_names(paths.LANDING_ZONE_PATH)
        if tarball_names:
            for tarball_name in tarball_names:
                exporter, exported, pid = self.parse_tarball_name(tarball_name)
                if exporter == None:
                    print("{0:45} {1:19} {2:6} {3}".format(tarball_name, "?", "?", "?"))
                else:
                    print("{0:45} {1:19} {2:6} {3}"
                          .format(tarball_name,
                                  datetime.datetime.fromtimestamp(int(exported)/1000).strftime('%Y-%m-%d %H:%M:%S'),
                                  pid, exporter.full_name + "(" + exporter.email + ")" + " - " + exporter.id))
        else:
            print("No exported tarballs remaining in the workspace")

    def display_staging_area_content(self):
        """
        Convenience method to handle tabular display of any residual staged datasets in the staging area.  These
        collections would have names corresponding to the dataset id they would have had they been successfully
        processed.
        """
        print("\nSTAGING AREA (Note: Any datasets there should be short-lived):")
        print("{}".format("Dataset Name"))
        staging_area_coll_names = self.manager.get_coll_names(paths.STAGING_PATH)
        if staging_area_coll_names:
            for staging_area_coll_name in staging_area_coll_names:
                print("{}".format(staging_area_coll_name))
        else:
            print("No unpacked tarballs (staged datasets) remaining in the workspace")

    def display_flags(self):
        """
        Convenience method to handle tabular display of flags in the workspace.  Presently, flags only refer to
        Galaxy exports.  The table always appears but the absence of flags is noted with a message.  This listing of
        flags shows the exporter but no messages in the case of a failed export.  That information is available
        via a user_report parameterized with the exporter's email.
        """
        print("\nEXPORT HISTORY:")
        self.generate_related_flags()
        Flag.display_header(True, False)
        if self.flags:
            for flag in self.flags:
                flag.display(True, False)
        else:
            print("No exports found in the workspace for this period")

    def display_events(self):
        """
        Convenience method to handle tabular display of events in the workspace.  The table always appears but the
        absence of events is noted with a message.  Generating events can take an excessive amount of time because
        each event data object must be opened and read to glean any useful information.  So it is advisable to limit
        the scope of the request by entering a period defined by start and end dates when requesting a workspace
        report.
        """
        print("\nEVENT HISTORY:")
        self.generate_related_events()
        Event.display_header()
        if self.events:
            for event in self.events:
                event.display(self.dashboard)
        else:
            print("No events found in the workspace for this period")

    def display(self):
        print("iRODS Workspace - id: {} - host: {}".format(self.id, self.dashboard.workspace_host))
        print("Default quota is {} Mb".format(self.quota))
        self.display_landing_zone_content()
        self.display_staging_area_content()
        self.display_inventory()
        self.display_flags()
        self.display_events()
