from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path


def healthz(request):
    return JsonResponse({"status": "ok"})


urlpatterns = [
    path("healthz", healthz),
    path("admin/", admin.site.urls),
    path("v1/", include("intel.urls")),
    path("v1/", include("orgs.urls")),
]
