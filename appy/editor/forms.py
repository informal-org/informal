from django import forms
from django.forms import ModelForm
from editor.models import App


class CreateAppForm(ModelForm):
    # ensure lower case
    slug = forms.SlugField(label="Subdomain (https://project-id.aasm.app)",
    widget=forms.TextInput(attrs={'placeholder': 'project-id'}) )
    class Meta:
        model = App
        fields = ['name', 'slug']
    