from django.shortcuts import render
from django.http import HttpResponse, JsonResponse
from django.views.generic.list import ListView
from django.views.generic.detail import DetailView
from django.views.generic.edit import CreateView, UpdateView
from django.contrib.auth.mixins import LoginRequiredMixin
from django.contrib.auth.decorators import login_required
from django.shortcuts import redirect
from editor.models import App, View


# Create your views here.
def hello(request):
    return HttpResponse("hello")

# class AppListView(LoginRequiredMixin, ListView):
#     model = App

#     def get_queryset(self):
#         return App.objects.filter(user=self.request.user)
    
@login_required
def editor(request):
    first_app = App.objects.filter(user=request.user).first()
    return redirect(first_app.get_absolute_url())


def check_app_permission(app, user):
    return app.user == user

@login_required
def api_apps(request):
    apps = App.objects.filter(user=request.user)
    app_details = []
    for app in apps:
        view_details = []
        views = View.objects.filter(app=app)
        for view in views:
            view_details.append({
                "id": view.id,
                "name": view.name,
                "mime_type": view.mime_type,
                "remote_url": view.remote_url,
                "pattern": view.pattern,
                "method_get": view.method_get,
                "method_post": view.method_post
            })
        app_details.append({
            "name": app.name,
            "domain": app.domain,
            "views": view_details
        })


    return JsonResponse({
        "apps": app_details
    })


