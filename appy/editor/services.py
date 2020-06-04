from editor.models import View
from editor.constants import DEFAULT_CONTENT
import shortuuid

def get_user_ip(request):
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        return x_forwarded_for.split(',')[0]
    else:
        return request.META.get('REMOTE_ADDR')


def get_user_properties(request, user=None):
    # TODO: Change to lb/cloudflare headers instead of appengine
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

    if not user and hasattr(request, 'user') and request.user.is_authenticated():
        user = request.user

    if user:
        context["email"] = user.email
        context["is_staff"] = user.is_staff

    return context





def create_home_view(app):
    view = View.objects.create(
        app=app, 
        name="Home",
        mime_type="application/aasm",
        pattern="/",
        pattern_regex="/",
        content=DEFAULT_CONTENT)
    return view

