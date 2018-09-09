from workspace.models import Docs


def create_doc(user, name="Untitled"):
    doc = Docs(name=name, owner=user, contents={})
    doc.save()
    return doc