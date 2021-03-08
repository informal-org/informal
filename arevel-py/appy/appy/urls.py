"""appy URL Configuration

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/2.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include, re_path
from django.views.generic import TemplateView
from django.conf import settings
from django.conf.urls.static import static

from editor.views import *

urlpatterns = [
    path('', TemplateView.as_view(template_name="index.html")),

    path('apps', AppListView.as_view()),
    path('apps/create', AppCreateView.as_view()),
    path('apps/<slug:app>/edit', AppEditView.as_view()),
    path('apps/<slug:slug>/views/create', ViewCreateView.as_view()),

    path('apps/<slug:app>/views/<slug:view>/edit', AppEditView.as_view()),

    # apps/test/edit
    # apps/test/views/create
    # apps/test/views/e123c32c/edit
    
    path('api/evaluate', evaluate),
    path('api/v1/', include('api.urls')),
    path('private/admin/', admin.site.urls),
    path('private/error/', error_view),
    path('private/config/', config_view),
    path('private/db_test', db_test),

    path('private/aasm_test', aasm_test),

    path('healthz', healthcheck),

    path('accounts/', include('allauth.urls')),

    path('terms/', TemplateView.as_view(template_name="legal/terms.html")),
    path('privacy/', TemplateView.as_view(template_name="legal/privacy.html")),

    path('docs/', TemplateView.as_view(template_name="docs/index.html")),
    path('docs/getting_started/', TemplateView.as_view(template_name="docs/getting_started.html")),
    # path('docs/getting_started/', TemplateView.as_view(template_name="docs/tutorial.html")),


]
