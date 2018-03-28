from django.conf.urls import include, url
from django.contrib import admin

from workspace.views import landing, demo, config, ycdemo

urlpatterns = [
    url(r'^$', landing),
    url(r'^private/config$', config),
    url(r'^private/admin/', include(admin.site.urls)),
    url(r'^accounts/', include('allauth.urls')),
    url(r'^plans/', include('plans.urls')),

    url(r'^ycdemo\/?', ycdemo),

    url(r'^demo\/?', demo),

]
