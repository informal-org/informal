from django.db import models
from django.contrib.auth.models import User
from django.contrib.postgres.fields import ArrayField
from django.utils.text import slugify
from editor.utils import *
import random
import string
import uuid

# Create your models here.
class App(models.Model):
    name = models.CharField(max_length=64)
    slug = models.SlugField(max_length=30, unique=True, db_index=True)
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

    def get_absolute_url(self):
        return '/apps/' + str(self.slug) + "/edit"


class View(models.Model):
    app = models.ForeignKey(App, on_delete=models.CASCADE)
    name = models.CharField(max_length=64, blank=True)
    uuid = models.UUIDField(db_index=True, default=uuid.uuid4, editable=False)
    root_cell = models.ForeignKey("Cell", on_delete=models.SET_NULL, null=True)

    mime_type = models.CharField(max_length=64)
    remote_url = models.URLField(null=True, blank=True)
    content = models.TextField(blank=True)
    # compiled_js = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    pattern = models.CharField(db_index=True, max_length=300)
    pattern_regex = models.CharField(db_index=True, max_length=300)

    method_get = models.BooleanField(default=True, db_index=True)
    method_post = models.BooleanField(default=True, db_index=True)

    def __str__(self):
        return self.name

    def get_edit_url(self):
        return "/apps/%s/views/%s/edit" % (str(self.app.slug), str(encode_uuid(self.uuid)))


class Cell(models.Model):
    app = models.ForeignKey(App, on_delete=models.CASCADE)
    uuid = models.UUIDField(db_index=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=64, blank=True, db_index=True)

    expr = models.TextField(blank=True)
    guard_expr = models.TextField(blank=True)

    docs = models.TextField(blank=True)
    
    # TODO: Type
    parent = models.ForeignKey("Cell", on_delete=models.CASCADE, null=True)

    params = ArrayField(models.CharField(max_length=64), blank=True, null=True)
    param_types = ArrayField(models.CharField(max_length=64), blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)    
    

# Each cell will have a reference to each of its ancestors up the tree to the root.
class Ancestor(models.Model):
    child = models.ForeignKey(Cell, on_delete=models.CASCADE, related_name="child_cells")
    ancestor = models.ForeignKey(Cell, on_delete=models.CASCADE, related_name="ancestor_cells")

    class Meta:
        unique_together = ["child", "ancestor"]

class Dependency(models.Model):
    base_cell = models.ForeignKey(Cell, on_delete=models.CASCADE, related_name="base_cells")
    ref_cell = models.ForeignKey(Cell, on_delete=models.CASCADE, related_name="ref_cells")
    name = models.CharField(max_length=64)

    class Meta:
            unique_together = ["base_cell", "ref_cell"]    


# class Route(models.Model):
#     # FK to app for querying efficiency without the additional join over view
#     app = models.ForeignKey(App, on_delete=models.CASCADE)
#     view = models.ForeignKey(View, on_delete=models.CASCADE)
#     name = models.CharField(null=True, max_length=64)
#     # extra_methods[]
