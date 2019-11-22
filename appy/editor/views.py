from django.shortcuts import render
from django.http import HttpResponse
from django.views.generic.list import ListView
from django.views.generic.detail import DetailView
from django.views.generic.edit import CreateView, UpdateView
from .models import *

# Create your views here.
def hello(request):
    return HttpResponse("hello")

class AppListView(ListView):
    model = App
    
