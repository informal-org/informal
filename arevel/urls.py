from django.conf.urls import include, url
from django.contrib import admin

from workspace.views import index, config

urlpatterns = [
    url(r'^$', index),
    url(r'^private/config$', config),
    url(r'^admin/', include(admin.site.urls)),
]
