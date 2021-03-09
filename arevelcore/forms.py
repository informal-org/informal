from allauth.account.forms import SignupForm
from django import forms
from django.forms import ModelForm

from .models import ArevelUser


class ArevelSignupForm(SignupForm):
    first_name = forms.CharField(max_length=30, label='First Name')
    last_name = forms.CharField(max_length=30, label='Last Name', required=False)

    def signup(self, request, user):
        user.first_name = self.cleaned_data['first_name']
        user.last_name = self.cleaned_data.get('last_name', '')
        user.save()
        return user
