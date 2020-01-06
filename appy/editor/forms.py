from django import forms
from django.forms import ModelForm
from editor.models import App


class CreateAppForm(ModelForm):
    class Meta:
        model = App
        fields = ['name', 'slug']
    