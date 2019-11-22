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
    print("Data:")
    print(request)
    body = json.loads(request.body)
    print(body)
    r = requests.post('http://localhost:9080/api/evaluate', 
        json = body,
        headers = {
            'Content-Type': 'application/json'
        })
    print("Request is")
    print(r)
    print(r.content)
    # return JsonResponse(r.json())
    return HttpResponse(r.content, content_type="application/json")