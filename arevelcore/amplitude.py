import requests
import time
import json
import logging

from django.conf import settings

from workspace.services import get_user_properties, get_user_ip

LOG = logging.getLogger(__name__)

# Heavily modified from
# https://github.com/atveit/amplitude-python/blob/master/amplitude/__init__.py

# Documentation of AmplitudeHTTP API:
#   https://amplitude.zendesk.com/hc/en-us/articles/204771828
#
# Convert Curl queries - such as below to - python:
#   https://curl.trillworks.com/
#
# Example HTTP Curl Query for Amplitude:
#   curl --data 'api_key=SOMEIDOFAKIND' --data 'event=[{"user_id":"john_doe@gmail.com", "event_type":"watch_tutorial", "user_properties":{"Cohort":"Test A"}, "country":"United States", "ip":"127.0.0.1", "time":1396381378123}]' https://api.amplitude.com/httpapi


class AmplitudeLogger:
    def __init__(self):
        self.api_key = settings.AMPLITUDE_KEY
        self.api_uri = "https://api.amplitude.com/httpapi"
        # TODO: Use a singleton session everywhere... 
        self.session = requests.Session()

    def create_event(self, request, event_type, event_properties, user=None):
        """
        :param request: Django request
        :param event_type: Required string - (Subject) Verb Object. Obmit subject when = User (implied). All lowercase.
        :param event_properties: Dictionary
        :param user_properties: Additional user properties

        :return:

        Ex. (User) created account
        """
        event = {}
        if not user and hasattr(request, 'user') and request.user.is_authenticated():
            user = request.user

        # Anonymous users SHOULD NOT be assigned a user id
        if user:
            # Convert from long to int to avoid "L"
            event["user_id"] = int(request.user.id)

        event["device_id"] = request.session.get("tk")

        event["event_type"] = event_type

        # integer epoch time in milliseconds
        event["time"] = int(time.time() * 1000)

        event["user_properties"] = get_user_properties(request, user)
        event["event_properties"] = event_properties

        event["ip"] = get_user_ip(request)

        event_package = [
            ('api_key', self.api_key),
            ('event', json.dumps([event])),
        ]

        LOG.debug(event)
        return event_package

    # data = [
    #  ('api_key', 'SOMETHINGSOMETHING'),
    #  ('event', '[{"device_id":"foo@bar", "event_type":"testing_tutorial", "user_properties":{"Cohort":"Test A"}, "country":"United States", "ip":"127.0.0.1", "time":1396381378123}]'),
    # ]
    def log_event(self, event):
        if not event:
            return

        if type(event) != list:
            event = [event]

        try:
            response = self.session.post(self.api_uri, data=event, timeout=3)
            LOG.info("Logging request response: " + str(response.status_code))
            LOG.info(response.content)
            return response
        except Exception as e:
            LOG.exception("Could not log to amplitude");
