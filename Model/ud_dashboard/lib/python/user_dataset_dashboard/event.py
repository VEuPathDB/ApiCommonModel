from __future__ import print_function
import json
import datetime


class Event:
    """
    This object holds information about irods events, which are saved as data objects in the events path under
    workspaces.
    """

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
            self.event_date = str(self.event_id)[:-8]
        except Exception as e:
            self.valid = False
            self.dataset_id = None
            self.message = getattr(e, 'message') or repr(e)

    @staticmethod
    def display_header():
        print("{0:19} {1:19} {2:12} {3:8} {4:8} {5:63}"
              .format("Event Date", "Event Id", "Dataset Id", "Type", "Action", "Recipient"))

    def display(self, dashboard):
        """
        Provides a display of the event contained within this Event object.  The action and recipient properties
        only have meaning in the case of a share or unshare event and are otherwise not shown.
        :param dashboard:
        """
        format_string = "{0:19} {1:19} {2:12} {3:8}"
        long_format_string = format_string + "{4:8} {5} ({6}) - {7}"
        if self.event == "share":
            recipient = dashboard.find_user_by_id(self.recipient_id)
            print(long_format_string
                  .format(datetime.datetime.fromtimestamp(int(self.event_date)).strftime('%Y-%m-%d %H:%M:%S'),
                          self.event_id, self.dataset_id, self.event, self.action,
                          recipient.full_name, recipient.email, self.recipient_id))
        else:
            print(format_string
                  .format(datetime.datetime.fromtimestamp(int(self.event_date)).strftime('%Y-%m-%d %H:%M:%S'),
                          self.event_id, self.dataset_id, self.event))
