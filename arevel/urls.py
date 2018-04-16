from django.core.urls import include, url
from django.contrib import admin
from django.views.generic import TemplateView

from workspace.views import landing, demo, config, ycdemo

urlpatterns = [
    url(r'^$', landing),
    url(r'^private/config$', config),
    url(r'^private/admin/', include(admin.site.urls)),
    url(r'^accounts/', include('allauth.urls')),
    url(r'^plans/', include('plans.urls')),

    url(r'^ycdemo\/?', ycdemo),

    url(r'^demo\/?', demo),

    url(r'^terms\/?$', TemplateView.as_view(template_name="legal/terms.html")),
    url(r'^privacy\/?$', TemplateView.as_view(template_name="legal/privacy.html")),

]
