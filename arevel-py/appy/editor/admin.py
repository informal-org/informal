from django.contrib import admin
import inspect
import sys
from .models import *
from django.contrib import admin



# Register your models here.
# admin.site.register(Collections)

@admin.register(View)
class ViewAdmin(admin.ModelAdmin):
    readonly_fields = ("uuid",)


# Auto register all the models

classes = inspect.getmembers(sys.modules['editor.models'], lambda member: inspect.isclass(member) and member.__module__ == "editor.models")
for class_name, clazz in classes:
    if clazz not in admin.site._registry:
        admin.site.register(clazz)