from django.db import models
from django.contrib.auth import get_user_model
from django.urls import reverse
from django_mysql.models import JSONField
import shortuuid
import json


class Docs(models.Model):
    uuid = models.CharField(default=shortuuid.uuid, editable=False, db_index=True, unique=True, max_length=22)
    date_created = models.DateTimeField(auto_now_add=True)
    date_updated = models.DateTimeField(auto_now=True, db_index=True)

    name = models.CharField(max_length=200)
    owner = models.ForeignKey(get_user_model())
    contents = JSONField(null=True)

    def get_absolute_url(self):
        return reverse('doc_details', kwargs={'uuid': self.uuid})

    def contents_str(self):
        return json.dumps(self.contents)
