from django.http import HttpResponse, JsonResponse
from django.conf import settings
from django.shortcuts import render


def index(request):
    # return HttpResponse("Hello, Arevel.")
    return render(request, "workspace.html")


def config(request):
    return JsonResponse({
        "is_prod": settings.IS_PROD,
        "debug": settings.DEBUG
    })