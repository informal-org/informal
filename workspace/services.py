from django.core.exceptions import PermissionDenied

from workspace.models import Docs


def create_doc(user, name="Untitled"):
    doc = Docs(name=name, owner=user, contents={})
    doc.save()
    return doc


def has_document_permission(request, doc):
    has_permission = request.user.is_authenticated() and doc.owner == request.user
    if not has_permission:
        raise PermissionDenied
    return has_permission