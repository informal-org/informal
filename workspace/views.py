from django.http import HttpResponse, JsonResponse
from django.conf import settings

def index(request):
    return HttpResponse("Hello, Arevel.")


def config(request):
    return JsonResponse({
        "is_prod": settings.IS_PROD,
        "debug": settings.DEBUG
    })