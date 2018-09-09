from django.conf.urls import include, url
from django.contrib import admin
from django.views.generic import TemplateView

from workspace.views import *

urlpatterns = [
    url(r'^$', landing),
    url(r'^private/config$', config),
    url(r'^private/admin/', include(admin.site.urls)),

    # Library URLs
    url(r'^accounts/', include('allauth.urls')),


    # Core functionality
    url(r'^docs$', docs_list, name='docs_list'),
    url(r'^docs/latest', latest_doc, name='latest_doc'),
    url(r'^docs/create', docs_create, name='docs_create'),
    url(r'^docs/(?P<uuid>\w{22})$', doc_details, name='doc_details'),


    # General App URLS
    url(r'^ycdemo\/?$', ycdemo),
    url(r'^terms\/?$', TemplateView.as_view(template_name="legal/terms.html")),
    url(r'^privacy\/?$', TemplateView.as_view(template_name="legal/privacy.html")),
]
