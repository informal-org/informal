from django.shortcuts import render
from django.http import HttpResponse, JsonResponse, HttpResponseServerError
from django.views.generic.list import ListView
from django.views.generic.detail import DetailView
from django.views.generic.edit import CreateView, UpdateView
from django.contrib.auth.mixins import LoginRequiredMixin
from django.contrib.auth.decorators import login_required
from django.conf import settings
from django.contrib.auth.models import User
from django.shortcuts import redirect
from editor.models import App, View
import requests
import json
import os
from dotenv import load_dotenv
load_dotenv()

# Create your views here.
def hello(request):
    return HttpResponse("hello")

# class AppListView(LoginRequiredMixin, ListView):
#     model = App

#     def get_queryset(self):
#         return App.objects.filter(user=self.request.user)
    

def check_app_permission(app, user):
    return app.user == user


def evaluate(request):
    r = requests.post('http://localhost:9080/api/evaluate', 
        data = request.body,
        headers = {
            'Content-Type': 'application/json'
        })
    return HttpResponse(r.content, content_type="application/json")


def error_view(request):
    raise Exception("Intentionally thrown Error View")

def config_view(request):
    load_dotenv()
    return JsonResponse({
        'MOO': os.getenv('MOO', 'undefined_moo'),
        'DEBUG': settings.DEBUG
    })

def db_test(request):
    elem = User.objects.first()
    return HttpResponse("OK")