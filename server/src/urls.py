from django.urls import path, include
from api.views import health, version
from django.http import JsonResponse
from django.conf import settings
from django.conf.urls.static import static
from admin_panel import react_dashboard_views

def root_view(request):
    return JsonResponse({"message": "SecureVOX Django API", "status": "ok"})

urlpatterns = [
    path("", root_view),
    path("health/", health),
    path("version/", version),
    
    # File statici dashboard React dalla root (PRIMA delle altre URL)
    path("static/<path:file_path>", react_dashboard_views.react_static_files, name="root_react_static"),
    path("manifest.json", react_dashboard_views.react_static_files, {"file_path": "../manifest.json"}, name="root_react_manifest"),
    
    path("api/", include("api.urls")),
    path("admin/", include("admin_panel.urls")),
    path("app-distribution/", include("app_distribution.urls")),
]

# Servire file media in modalità di sviluppo
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
