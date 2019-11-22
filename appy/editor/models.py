from django.db import models
from django.contrib.auth.models import User
from django.utils.text import slugify
import random
import string


# Create your models here.
class App(models.Model):
    name = models.CharField(max_length=64)
    # slug = models.SlugField(max_length=64, unique=True)
    domain = models.CharField(max_length=64, db_index=True, unique=True)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    # environment

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    @staticmethod
    def generate_slug(name):
        slug = slugify(name)
        slug += '-' + str(random.randint(0, 99999))
        return slug

    def __str__(self):
        return self.domain


class View(models.Model):
    app = models.ForeignKey(App, on_delete=models.CASCADE)
    name = models.CharField(max_length=64, blank=True)
    # slug = models.SlugField(max_length=64)

    mime_type = models.CharField(max_length=64)
    remote_url = models.URLField(null=True, blank=True)
    content = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    pattern = models.CharField(db_index=True, max_length=300)
    pattern_regex = models.CharField(db_index=True, max_length=300)

    method_get = models.BooleanField(default=True, db_index=True)
    method_post = models.BooleanField(default=True, db_index=True)

    def __str__(self):
        return self.name


# class Route(models.Model):
#     # FK to app for querying efficiency without the additional join over view
#     app = models.ForeignKey(App, on_delete=models.CASCADE)
#     view = models.ForeignKey(View, on_delete=models.CASCADE)
#     name = models.CharField(null=True, max_length=64)
#     # extra_methods[]
