from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.core.exceptions import PermissionDenied
from django.http import HttpResponse, JsonResponse
from django.conf import settings
from django.shortcuts import render, redirect, get_object_or_404

import logging
import json

from django.urls import reverse

from workspace.services import *

LOG = logging.getLogger(__name__)


def landing(request):
    logging.info("Homepage req")
    # return HttpResponse("Hello, Arevel.")
    # return render(request, "index.html")
    if request.user.is_authenticated():
        return redirect(reverse('docs_list'))
    return render(request, "landing.html")


@login_required
def docs_list(request):
    docs = Docs.objects.filter(owner=request.user)
    return render(request, 'docs_list.html', context={'docs': docs})


@login_required
def docs_create(request):
    doc = create_doc(request.user)
    return redirect(doc.get_absolute_url())


@login_required
def latest_doc(request):
    # Automatically create or get the first doc and redirect there.
    # So users start in the detail view rather than the list view.
    doc = Docs.objects.filter(owner=request.user).order_by("date_updated").first()
    if not doc:
        doc = create_doc(request.user)
    return redirect(doc.get_absolute_url())


@login_required
def doc_details(request, uuid):
    doc = get_object_or_404(Docs, uuid=uuid)
    has_document_permission(request, doc)
    if request.method == 'POST':
        # Since this is json format, should be safe against script injection...
        raw_contents = request.POST.get('contents', '')
        contents = json.loads(raw_contents)
        doc.name = request.POST.get('name', '');
        doc.contents = contents
        doc.save()
        return HttpResponse("OK")

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