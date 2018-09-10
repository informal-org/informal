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


def get_user_ip(request):
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        return x_forwarded_for.split(',')[0]
    else:
        return request.META.get('REMOTE_ADDR')


def get_user_properties(request):
    city_lat, city_long = request.META.get('X-AppEngine-City', ",").split(",")
    # TODO: User agent parsing.
    # Any other info from social auth
    context = {
        "tk": request.session.get("tk", ""),
        "ua": request.META.get("HTTP_USER_AGENT", ""),
        "ip": get_user_ip(request),
        "country": request.META.get('X-AppEngine-Country', ""),  # US
        "region": request.META.get('X-AppEngine-Region', ""),    # ca
        "city": request.META.get('X-AppEngine-City', ""),        # norwalk
        "location_lat": city_lat,
        "location_lng": city_long,
    }
    if request.user.is_authenticated():
        context["email"] = request.user.email
        context["is_staff"] = request.user.is_staff

    return context