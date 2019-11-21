from django.db import models
from django.contrib.auth.models import User
import random
import string


# Create your models here.
class App(models.Model):
    name = models.CharField(max_length=64)
    # domain is used as the public identifier
    domain = models.CharField(max_length=64, db_index=True, unique=True)
    # environment

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

class AppOwner(models.Model):
    """
    Multiple users can have ownership over an app with varying levels of permissions.
    """
    app = models.ForeignKey(App, on_delete=models.CASCADE)
    user = models.ForeignKey(User, on_delete=models.CASCADE)


class View(models.Model):
    app = models.ForeignKey(App, on_delete=models.CASCADE)
    name = models.CharField(max_length=64, blank=True)
    slug = models.SlugField(max_length=64)

    mime_type = models.CharField(max_length=64)
    remote_url = models.URLField(null=True)
    content = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


class Route(models.Model):
    # FK to app for querying efficiency without the additional join over view
    app = models.ForeignKey(App, on_delete=models.CASCADE)
    view = models.ForeignKey(View, on_delete=models.CASCADE)

    name = models.CharField(null=True, max_length=64)

    pattern = models.CharField(db_index=True, max_length=300)
    pattern_regex = models.CharField(db_index=True, max_length=300)

    method_get = models.BooleanField(default=True, db_index=True)
    method_post = models.BooleanField(default=True, db_index=True)

    # extra_methods[]
