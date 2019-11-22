from django.conf.urls import url, include
from django.contrib.auth.models import User
from editor.models import App, View
from rest_framework import routers, serializers, viewsets

# Serializers define the API representation.
class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['url', 'username']

# TODO: View summary serializer
class ViewSerializer(serializers.ModelSerializer):
    class Meta:
        model = View
        fields = ['id', 'name', 'mime_type', 'remote_url', 'content', 'pattern', 'method_get', 'method_post']


class AppSerializer(serializers.ModelSerializer):
    view_set = ViewSerializer(many=True)
    class Meta:
        model = App
        fields = ['name', 'domain', 'view_set']


# ViewSets define the view behavior.
class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer


class AppViewSet(viewsets.ModelViewSet):
    queryset = App.objects.all()
    serializer_class = AppSerializer

    def get_queryset(self):
        return App.objects.filter(user=self.request.user)

class ViewViewSet(viewsets.ModelViewSet):
    queryset = View.objects.all()
    serializer_class = ViewSerializer

    def get_queryset(self):
        return View.objects.filter(app__user=self.request.user)



# Routers provide an easy way of automatically determining the URL conf.
router = routers.DefaultRouter()
router.register(r'users', UserViewSet)
router.register(r'apps', AppViewSet)
router.register(r'views', AppViewSet)

# Wire up our API using automatic URL routing.
# Additionally, we include login URLs for the browsable API.
urlpatterns = [
    url(r'^', include(router.urls)),
    url(r'^api/', include('rest_framework.urls', namespace='rest_framework'))
]