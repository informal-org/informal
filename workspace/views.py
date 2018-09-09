from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.http import HttpResponse, JsonResponse
from django.conf import settings
from django.shortcuts import render

import logging

from workspace.services import *


def landing(request):
    logging.info("Homepage req")
    # return HttpResponse("Hello, Arevel.")
    # return render(request, "index.html")
    return render(request, "landing.html")


def docs_list(request):
    pass


def has_document_permission(doc, request):
    return request.user.is_authenticated() and doc.owner == request.user


@login_required
def first_doc(request):
    # Automatically create or get the first doc and redirect there.
    # So users start in the detail view rather than the list view.
    doc = Docs.objects.filter(owner=request.user).order_by("date_updated").first()
    if not doc:
        doc = create_doc(request.user)
    return doc


def doc_details(request, doc_id):
    return render(request, "doc.html", context={})


def config(request):
    logging.info("Config req")
    return JsonResponse({
        "is_prod": settings.IS_PROD,
        "debug": settings.DEBUG
    })


def ycdemo(request):
    logging.info("YC Demo")
    return render(request, 'yc.html')