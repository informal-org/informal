from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.core.exceptions import PermissionDenied
from django.http import HttpResponse, JsonResponse
from django.conf import settings
from django.shortcuts import render, redirect, get_object_or_404

import logging

from django.urls import reverse

from workspace.services import *


def landing(request):
    logging.info("Homepage req")
    # return HttpResponse("Hello, Arevel.")
    # return render(request, "index.html")
    return render(request, "landing.html")


@login_required
def docs_list(request):
    pass


@login_required
def latest_doc(request):
    # Automatically create or get the first doc and redirect there.
    # So users start in the detail view rather than the list view.
    doc = Docs.objects.filter(owner=request.user).order_by("date_updated").first()
    if not doc:
        doc = create_doc(request.user)
    return redirect(reverse('doc_details', kwargs={'uuid': doc.uuid}))


@login_required
def doc_details(request, uuid):
    doc = get_object_or_404(Docs, uuid=uuid)
    has_document_permission(request, doc)
    return render(request, "doc.html", context={'doc': doc})


def config(request):
    logging.info("Config req")
    return JsonResponse({
        "is_prod": settings.IS_PROD,
        "debug": settings.DEBUG
    })


def ycdemo(request):
    logging.info("YC Demo")
    return render(request, 'yc.html')