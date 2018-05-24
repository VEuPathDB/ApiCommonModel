from __future__ import print_function
import re
import datetime
import paths
from prettytable import PrettyTable
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
        self.inventory = []
        self.flags = []
        self.invalid_flags = None
        self.events = []
        self.invalid_events = None

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

    def generate_inventory(self, show_dataset_owners):
        """
        Generates a listing of the workspace users contents (i.e., users and the datasets they own.
        :param show_dataset_owners: when true, the inventory will contain only users currently owning
        datasets.  If false, the inventory will include all users having a presence in irods.  Also
        when all users are included, the inventory list is sorted by dataset id.  Otherwise the
        inventory list is sorted by user email address.
        """
        user_coll_names = self.manager.get_coll_names(paths.USERS_PATH)
        if user_coll_names:
            for user_coll_name in user_coll_names:
                user = self.dashboard.find_user_by_id(user_coll_name)
                datasets_coll_path = paths.USER_DATASETS_COLLECTION_TEMPLATE.format(user_coll_name)
                dataset_coll_names = self.manager.get_coll_names(datasets_coll_path)
                if dataset_coll_names:
                    for ctr, dataset_coll_name in enumerate(dataset_coll_names):
                        self.inventory.append({"user": user, "dataset": dataset_coll_name, "ctr": ctr})
                else:
                    if not show_dataset_owners:
                        self.inventory.append({"user": user, "dataset": "", "ctr": 0})
            if show_dataset_owners:
                self.inventory.sort(key=lambda i: i['dataset'])
            else:
                self.inventory.sort(key=lambda i: (i['user'].email, i['ctr']))

    def generate_related_flags(self):
        """
        Generates a list of Flag objects, sorted by exported dataset create time, created during the period specified.
        If no period is specified, all flags are displayed.  If only a start date is specified, only those flags created
        between then and the current time are displayed.  If only an end date is specified, only those flags created
        up to but not including the end date are displayed.  Note that any invalid flags are separated out into a
        separate list for special display.
        """
        flag_dataobj_names = self.manager\
            .get_dataobj_names_created_between(paths.FLAGS_PATH, self.start_date, self.end_date)
        candidate_flags = [Flag(self.dashboard, flag_dataobj_name) for flag_dataobj_name in flag_dataobj_names]
        self.flags = [item for item in candidate_flags if item.valid]
        self.invalid_flags = list(set(candidate_flags) - set(self.flags))
        self.flags.sort(key=lambda f: f.exported)

    def generate_related_events(self):
        """
        Generates a list of Event objects, sorted by event creation time, created during the period specified.
        If no period is specified, all events are displayed.  If only a start date is specified, only those events
        created between then and the current time are displayed.  If only an end date is specified, only those events
        created up to but not including the end date are displayed.  Note that any invalid events are separated out
        into a separate list for special display.
        """
        candidate_events = []
        event_dataobj_names = self.manager\
            .get_dataobj_names_created_between(paths.EVENTS_PATH, self.start_date, self.end_date)
        for event_dataobj_name in event_dataobj_names:
            event_path = paths.EVENTS_DATA_OBJECT_TEMPLATE.format(event_dataobj_name)
            event = Event(event_dataobj_name, self.manager.get_dataobj_data(event_path))
            candidate_events.append(event)
        self.events = [item for item in candidate_events if item.valid]
        self.invalid_events = list(set(candidate_events) - set(self.events))
        self.events.sort(key=lambda e: e.event_id)

    def parse_tarball_name(self, name):
        """
        Pulls apart the tarball data object's name in order to extract the the user, the export date and the export pid.
        These components should match up with at least two export flags.
        :param name: tarball data object name
        :return: tuple providing components of parsed data object name:  exporter, exported time, and export pid.  If
        the data object's name format is not observed, None is returned.
        """
        matches = re.match(r'dataset_u(.*)_t(.*)_p(.*).tgz', name, flags=0)
        if matches:
            exporter = self.dashboard.find_user_by_id(matches.group(1))
            return exporter, matches.group(2), matches.group(3)
        else:
            return None, None, None

    def display_properties(self):
        """
        Convenience method to handle a key : value display of workspace properties.
        """
        print("\nPROPERTIES:")
        properties_table = PrettyTable(["Property", "Value"])
        properties_table.align = "l"
        properties_table.add_row(["Id", self.id])
        properties_table.add_row(["Host", self.manager.get_host()])
        properties_table.add_row(["Default quota", self.quota + " Mb"])
        print(properties_table)

    def display_inventory(self, show_dataset_owners):
        """
        Prints a summary view of the workspace users contents
        :param show_dataset_owners: boolean controlling the content and arrangement of the inventory data.
        """
        self.generate_inventory(show_dataset_owners)
        print("\nINVENTORY:")
        inventory_table = PrettyTable(["User", "Dataset Id"])
        inventory_table.align["User"] = "l"
        inventory_table.align["Dataset Id"] = "r"
        if self.inventory:
            for item in self.inventory:
                if not show_dataset_owners and item['ctr'] > 0:
                    row = ["", item['dataset']]
                else:
                    row = [item['user'].formatted_user(), item['dataset']]
                inventory_table.add_row(row)
            print(inventory_table)
        else:
            print("Workspace currently unused.")

    def display_landing_zone_content(self):
        """
        Convenience method to handle tabular display of any residual tarballs in the landing zone.  Tarballs should
        have the name format: dataset__u<user id>_t<timestamp in millsec>_p<pid>.tgz.  Any items matching this
        format should have a corresponding pair of export flags in the flags collection.  Anything that does not
        match the naming convention is simply detritus.
        """
        print("\nLANDING ZONE (Note: Any tarballs there should be short-lived):")
        landing_zone_table = PrettyTable(["Name", "Export Date", "Pid", "Exporter"])
        landing_zone_table.align["Name"] = "l"
        landing_zone_table.align["Export Date"] = "c"
        landing_zone_table.align["Pid"] = "r"
        landing_zone_table.align["Exporter"] = "l"
        tarball_names = self.manager.get_dataobj_names(paths.LANDING_ZONE_PATH)
        if tarball_names:
            for tarball_name in tarball_names:
                exporter, exported, pid = self.parse_tarball_name(tarball_name)
                if exporter is None:
                    # tarball name not parseable
                    landing_zone_table.add_row([tarball_name, "?", "?", "?"])
                else:
                    pass
                    row = [tarball_name,
                           datetime.datetime.fromtimestamp(int(exported)/1000).strftime('%Y-%m-%d %H:%M:%S'),
                           pid, exporter.formatted_user()]
                    landing_zone_table.add_row(row)
            print(landing_zone_table)
        else:
            print("No exported tarballs remaining in the workspace")

    def display_staging_area_content(self):
        """
        Convenience method to handle tabular display of any residual staged datasets in the staging area.  These
        collections would have names corresponding to the dataset id they would have had, had they been successfully
        processed.
        """
        print("\nSTAGING AREA (Note: Any datasets there should be short-lived):")
        staging_area_coll_names = self.manager.get_coll_names(paths.STAGING_PATH)
        if staging_area_coll_names:
            staging_area_table = PrettyTable(["Dataset Name", "Create Date"])
            staging_area_table.align["Dataset Name"] = "r"
            staging_area_table.align["Create Date"] = "c"
            for staging_area_coll_name in staging_area_coll_names:
                staging_area_coll_path = paths.STAGING_COLLECTION.format(staging_area_coll_name)
                utc_create_time = self.manager.get_coll_create_time(staging_area_coll_path)
                create_time = self.dashboard.datetime_from_utc_to_local(utc_create_time)
                staging_area_table.add_row([staging_area_coll_name, create_time])
            print(staging_area_table)
        else:
            print("No unpacked tarballs (staged datasets) remaining in the workspace")

    def display_flags(self):
        """
        Convenience method to handle tabular display of flags in the workspace.  Presently, flags only refer to
        Galaxy exports.  The table always appears but the absence of flags is noted with a message.  This listing of
        flags shows the exporter but no messages in the case of a failed export.  That information is available
        via a user_report parameterized with the exporter's email.
        """
        self.generate_related_flags()
        Flag.display(self.flags, True, False)

    def display_invalid_flags(self):
        """
        Convenience method to print out the names of those data objects in the flags collection that do not conform
        to the flag naming convention and as such, cannot be parsed.
        """
        if self.invalid_flags:
            print("\nFLAGS NOT RECOGNIZED AS EXPORTS:")
            invalid_flags_table = PrettyTable(["Flag data object name"])
            invalid_flags_table.align = "l"
            for flag in self.invalid_flags:
                invalid_flags_table.add_row([flag.name])
            print(invalid_flags_table)

    def display_events(self):
        """
        Convenience method to handle tabular display of events in the workspace.  The table always appears but the
        absence of events is noted with a message.  Generating events can take an excessive amount of time because
        each event data object must be opened and read to glean any useful information.  So it is advisable to limit
        the scope of the request by entering a period defined by start and end dates when requesting a workspace
        report.
        """
        self.generate_related_events()
        Event.display(self.dashboard, self.events)

    def display_invalid_events(self):
        """
        Convenience method to print out the names of those data objects in the events collection that contains no
        or incomplete json data.  Any error message available is provided to help diagnose the problem.
        """
        if self.invalid_events:
            print("\nINVALID EVENTS:")
            invalid_events_table = PrettyTable(["Event file name", "Reason"])
            invalid_events_table.align = "l"
            for event in self.invalid_events:
                invalid_events_table.add_row([event.name, event.message])
            print(invalid_events_table)

    def display(self, show_dataset_owners):
        """
        Full featured display of workspace.  Invalid flag (export) and event displays are produced only if invalid
        flags or events exist.
        """
        print("\nWORKSPACE REPORT from {} through {}"
              .format(self.start_date.strftime('%Y-%m-%d'),
                      (self.end_date - datetime.timedelta(days=1)).strftime('%Y-%m-%d')))
        self.display_properties()
        self.display_landing_zone_content()
        self.display_staging_area_content()
        self.display_inventory(show_dataset_owners)
        self.display_flags()
        self.display_invalid_flags()
        self.display_events()
        self.display_invalid_events()
        print("")
