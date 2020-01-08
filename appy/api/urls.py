from django.conf.urls import url, include
from django.contrib.auth.models import User
from editor.models import App, View
from rest_framework import routers, serializers, viewsets

# TODO: Separate view summary serializer without the content field for compactness
class ViewSerializer(serializers.ModelSerializer):
    class Meta:
        model = View
        fields = ['uuid', 'name', 'mime_type', 'remote_url', 'content', 'pattern', 'method_get', 'method_post']
        read_only_fields = ['uuid']
        lookup_field = 'uuid'
        extra_kwargs = {
            'url': {'lookup_field': 'slug'}
        }

class ViewSetSerializer(serializers.ModelSerializer):
    class Meta:
        model = View
        fields = ['uuid', 'name', 'mime_type', 'remote_url', 'method_get', 'method_post']
        lookup_field = 'uuid'
        read_only_fields = ['uuid']

class AppSerializer(serializers.ModelSerializer):
    view_set = ViewSetSerializer(many=True)
    class Meta:
        model = App
        fields = ['name', 'slug', 'domain', 'view_set']
        read_only_fields = ['view_set']
        lookup_field = 'slug'


class AppViewSet(viewsets.ModelViewSet):
    queryset = App.objects.all()
    serializer_class = AppSerializer
    # Restrict APP modification via the API
    http_method_names = ['get', 'head']
    lookup_field = 'slug'

    def get_queryset(self):
        return App.objects.filter(user=self.request.user)


class ViewViewSet(viewsets.ModelViewSet):
    queryset = View.objects.all()
    serializer_class = ViewSerializer
    lookup_field = 'uuid'

    def get_queryset(self):
        return View.objects.filter(app__user=self.request.user)



# Routers provide an easy way of automatically determining the URL conf.
router = routers.DefaultRouter()
router.register(r'apps', AppViewSet)
router.register(r'views', ViewViewSet)

# Wire up our API using automatic URL routing.
# Additionally, we include login URLs for the browsable API.
urlpatterns = [
    url(r'^', include(router.urls)),
    url(r'^api/', include('rest_framework.urls', namespace='rest_framework'))
]