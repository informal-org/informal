import logging

LOG = logging.getLogger(__name__)

class LoggingMiddleware(object):
    def process_response(self, request, response):
        metrics = {
            "action": "pgreq",
            "path": request.path, 
            "method": request.method, 
            "referer": request.META.get("HTTP_REFERER", ""),
            "ua": request.META.get("HTTP_USER_AGENT", ""),
            "query_string": request.META.get("QUERY_STRING", "")
        }
        # print metrics
        LOG.info("page request")
        LOG.info(metrics)
        return response
