from django.shortcuts import render
from django.http import HttpResponse, JsonResponse, HttpResponseServerError
from django.views.generic.list import ListView
from django.views.generic.detail import DetailView
from django.views.generic.edit import CreateView, UpdateView
from django.contrib.auth.mixins import LoginRequiredMixin, UserPassesTestMixin
from django.contrib.auth.decorators import login_required
from django.conf import settings
from django.contrib.auth.models import User
from django.shortcuts import redirect
from editor.models import App, View
from editor.forms import CreateAppForm
from editor.services import create_home_view
from editor.constants import DEFAULT_CONTENT
from editor.utils import decode_uuid
from api.urls import ViewSerializer
import requests
import json
import os
from dotenv import load_dotenv
load_dotenv()

# Create your views here.
def hello(request):
    return HttpResponse("hello")

class AppListView(LoginRequiredMixin, ListView):
    model = App

    def get_queryset(self):
        return App.objects.filter(user=self.request.user)

class AppPermissionMixin(UserPassesTestMixin):
    def test_func(self):
        return self.get_object().user == self.request.user

class ViewPermissionMixin(UserPassesTestMixin):
    def test_func(self):
        return self.get_object().app.user == self.request.user

class AppEditView(LoginRequiredMixin, DetailView, ViewPermissionMixin):
    model = View

    def get_object(self):
        # return App.objects.filter(slug=self.kwargs["app"])
        if hasattr(self, '_cached_obj'):
            return self._cached_obj
        
        if 'view' in self.kwargs:
            view_uuid = decode_uuid(self.kwargs['view'])
            self._cached_obj = View.objects.filter(app__slug=self.kwargs["app"], 
            uuid=view_uuid).first()
            return self._cached_obj
        else:
            self._cached_obj = View.objects.filter(app__slug=self.kwargs["app"]).first()
            return self._cached_obj

    # def get_context_data(self, **kwargs):
    #     context = super().get_context_data(**kwargs)
    #     serialized_view = ViewSerializer(self.get_object())
    #     context["view_json"] = json.dumps(serialized_view.data)
    #     return context

class AppCreateView(LoginRequiredMixin, CreateView, AppPermissionMixin):
    model = App
    form_class = CreateAppForm

    def form_valid(self, form):
        obj = form.save(commit=False)
        obj.user = self.request.user
        obj.domain = obj.slug + ".aasm.app"
        response = super(AppCreateView, self).form_valid(form)
        
        create_home_view(obj)

        return response

    

class ViewCreateView(LoginRequiredMixin, DetailView, AppPermissionMixin):
    model = App
    
    def post(self, *args, **kwargs):
        app = self.get_object()
        view = View.objects.create(
            app=app, 
            name="New View",
            mime_type="application/aasm",
            pattern="/new_view",
            pattern_regex="/new_view",
            content=DEFAULT_CONTENT)
            
        return redirect(view.get_edit_url())




def check_app_permission(app, user):
    return app.user == user


def evaluate(request):
    r = requests.post(settings.AASM_INTERNAL_HOST + '/api/evaluate', 
        data = request.body,
        headers = {
            'Content-Type': 'application/json'
        })
    return HttpResponse(r.content, content_type="application/json")


def create_app(request):
    return HttpResponse("OK")

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

def aasm_test(request):
    r = requests.get(settings.AASM_INTERNAL_HOST)
    return HttpResponse(r.content)

def healthcheck(request):
    return HttpResponse("OK")