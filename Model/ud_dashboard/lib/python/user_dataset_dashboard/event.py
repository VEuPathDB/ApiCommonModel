from __future__ import print_function
import json
import datetime
from prettytable import PrettyTable


class Event:
    """
    This object holds information about irods events, which are saved as data objects in the events path under
    workspaces.
    """

    EVENT_TYPES = {'INSTALL': 'install', 'SHARE': 'share', 'UNINSTALL': 'uninstall'}

    def __init__(self, event_name, event_json):
        """
        Populate a new event object with the data obtained from an event data object which is in a json format.  Note
        that the event id is a concatenation of a timestamp in sec and an 8 digit pid.
        :param event_json: event data object
        """
        self.valid = True
        try:
            self.name = event_name
            event_data = json.loads(event_json)
            self.event = event_data["event"]
            self.action = event_data.get("action")
            self.recipient_id = event_data.get("recipient")
            self.dataset_id = event_data["datasetId"]
            self.event_id = event_data["eventId"]
            self.owner_id = event_data["owner"]
            self.event_date = str(self.event_id)[:-8]
        except Exception as e:
            self.valid = False
            self.dataset_id = None
            self.message = getattr(e, 'message') or repr(e)

    @staticmethod
    def display(dashboard, events):
        """
        Class method that takes in a list of event objects and displays them.  The absence of events is noted
        with a message.
        :param dashboard:
        :param events: set of event objects to display
        """
        print("\nEVENT HISTORY:")
        if events:
            event_table = PrettyTable(["Event Date", "Event Id", "Dataset Id", "Type", "Action", "Recipient"])
            event_table.align["Dataset Id"] = "r"
            event_table.align["Type"] = "l"
            event_table.align["Action"] = "l"
            event_table.align["Recipient"] = "l"
            for event in events:
                row = [datetime.datetime.fromtimestamp(int(event.event_date)).strftime('%Y-%m-%d %H:%M:%S'),
                       event.event_id, event.dataset_id, event.event]
                if event.event == Event.EVENT_TYPES['SHARE']:
                    recipient = dashboard.find_user_by_id(event.recipient_id)
                    row.extend([event.action, recipient.formatted_user()])
                else:
                    row.extend(["", ""])
                event_table.add_row(row)
            print(event_table)
        else:
            print("No events were found for the given circumstances.")
