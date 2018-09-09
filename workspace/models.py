from django.db import models
import shortuuid
from django.contrib.auth import get_user_model
from django_mysql.models import JSONField


class Docs(models.Model):
    name = models.CharField(max_length=200)
    uuid = models.CharField(default=shortuuid.uuid, editable=False, db_index=True, unique=True)
    date_created = models.DateTimeField(auto_now_add=True)
    date_updated = models.DateTimeField(auto_now=True, db_index=True)
    owner = models.ForeignKey(get_user_model())
    contents = JSONField(null=True)


    def get_absolute_url(self):
        return '/docs/' + self.uuid


