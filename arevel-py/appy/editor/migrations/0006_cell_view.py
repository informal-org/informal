from django.db import migrations, models
import json
from editor.utils import decode_uuid, Sync
from editor.services import get_ancestors


def create_ancestors(Ancestor, cell):
    target = get_ancestors(cell)
    print("Target: " + str(target))
    current = list(Ancestor.objects.filter(child=cell).values_list("ancestor__id"))
    print("Current: " + str(current))
    sync = Sync(current, target)
    print("Ignore: " + str(sync.existing))
    print("Create: " + str(sync.create))
    print("Remove: " + str(sync.remove))
    Ancestor.objects.bulk_create([
        Ancestor(child=cell, ancestor_id=a) for a in sync.create
    ])
    Ancestor.objects.filter(child=cell, ancestor__in=list(sync.remove)).delete()
    


# Create a root cell for each view. Link to view.
# Then unroll the content cell structure hierarchy into cells.
def create_child_cells(Cell, Ancestor, root, contents):
    for body in contents["body"]:
        uuid = decode_uuid(body["id"])
        print("Creating child cell for : " + str(uuid) + " from : " + str(body["id"]))
        c = Cell.objects.create(app=root.app, 
        uuid=uuid,
        parent=root,
        name=body.get("name", ""),
        expr=body.get("expr", ""),
        docs=body.get("docs", ""))
        # Skipping params as it's not set for any existing data - only for future use.
        # Also create an ancestor link
        create_ancestors(Ancestor, c)
        


def view_to_cells(apps, schema_editor):
    View = apps.get_model('editor', 'View')
    Cell = apps.get_model('editor', 'Cell')
    Ancestor = apps.get_model('editor', 'Ancestor')
    for view in View.objects.filter(root_cell__isnull=True):
        root = Cell.objects.create(app=view.app, name=view.name)
        if view.content:
            print("JSON contents: " + str(view.content))
            contents = json.loads(view.content)
            create_child_cells(Cell, Ancestor, root, contents)
            view.root_cell = root
            view.save()


def undo_view_to_cells(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('editor', '0005_auto_20200822_0106'),
    ]

    operations = [
        migrations.RunPython(view_to_cells, reverse_code=undo_view_to_cells),
    ]

