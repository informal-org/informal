from django import template

register = template.Library()

@register.filter
def getitem(d, key):
    return d.get(str(key).lower(), "")