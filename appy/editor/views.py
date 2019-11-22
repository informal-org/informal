from django.shortcuts import render
from django.http import HttpResponse, JsonResponse
from django.views.generic.list import ListView
from django.views.generic.detail import DetailView
from django.views.generic.edit import CreateView, UpdateView
from django.contrib.auth.mixins import LoginRequiredMixin
from django.contrib.auth.decorators import login_required
from django.shortcuts import redirect
from editor.models import App, View
import requests
import json

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