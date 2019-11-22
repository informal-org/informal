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
    path('editor', TemplateView.as_view(template_name="editor/index.html")),
    path('api/v1/', include('api.urls')),
    path('private/admin/', admin.site.urls),

    # path('apps', AppListView.as_view()),
    # path('apps', AppListView.as_view()),

    # url(r'^create$', CreateTableView.as_view()),
    # url(r'^(?P<table_id>[-\w]+)$', DashTableView.as_view()),
    # url(r'^(?P<table_id>[-\w]+)/add$', DataViewAdd.as_view()),
    # url(r'^(?P<table_id>[-\w]+)/edit/new$', CreateFieldView.as_view()),
]
