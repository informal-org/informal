from django.http import HttpResponse, JsonResponse
from django.conf import settings
from django.shortcuts import render

import logging


def landing(request):
    logging.info("Homepage req")
    # return HttpResponse("Hello, Arevel.")
    # return render(request, "index.html")
    return render(request, "landing.html")

def demo(request):
    # return HttpResponse("Hello, Arevel.")
    return render(request, "index.html")


def config(request):
    logging.info("Config req")
    return JsonResponse({
        "is_prod": settings.IS_PROD,
        "debug": settings.DEBUG
    })

def ycdemo(request):
    logging.info("YC Demo")
    return render(request, 'yc.html')