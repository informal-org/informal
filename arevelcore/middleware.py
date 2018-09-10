import logging
import shortuuid
from django.urls import resolve

from arevelcore.amplitude import AmplitudeLogger

LOG = logging.getLogger(__name__)


amp = AmplitudeLogger()


class LoggingMiddleware(object):

    def process_response(self, request, response):
        context = {
            "path": request.path,
            "page_name": resolve(request.path_info).url_name or "",
            "method": request.method,
            "referer": request.META.get("HTTP_REFERER", ""),
            "query_string": request.META.get("QUERY_STRING", "")
        }
        # print metrics
        LOG.info("page request")
        LOG.info(context)
        event = amp.create_event(request, "request page", context)
        amp.log_event(event)
        return response


class IdentifierMiddleware(object):

    def process_request(self, request):
        uid = request.session.get("tk", "")
        if not uid:
            request.session['tk'] = shortuuid.uuid()

