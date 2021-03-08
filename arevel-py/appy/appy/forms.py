from allauth.account.forms import SignupForm
from django import forms
from django.forms import ModelForm

from django.contrib.auth.models import User


class AppySignupForm(SignupForm):
    full_name = forms.CharField(max_length=100, label='Full name')

    field_order = ['full_name', 'email', 'password1']

    def signup(self, request, user):
        full_name = self.cleaned_data['full_name']
        parts = full_name.split(" ")
        first_name = parts[0]
        last_name = " ".join(parts[1:])
        user.first_name = first_name
        user.last_name = last_name
        user.save()
        return user
