from django.db import models
import uuid


class Docs(models.Model):
    name = models.CharField(max_length=200)
    created_date = models.DateTimeField(auto_now_add=True)
    last_updated = models.DateTimeField(auto_now=True)


class BetaSignup(models.Model):
    email = models.EmailField()
    uid = models.UUIDField(default=uuid.uuid4, editable=False, db_index=True)