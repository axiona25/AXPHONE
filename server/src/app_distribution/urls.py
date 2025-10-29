from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

# Router per le API REST
router = DefaultRouter()
router.register(r'builds', views.AppBuildViewSet)
router.register(r'feedback', views.AppFeedbackViewSet)

app_name = 'app_distribution'

urlpatterns = [
    # API REST
    path('api/', include(router.urls)),
    
    # Interfaccia web
    path('', views.app_distribution_index, name='index'),
    path('login/', views.app_distribution_login, name='login'),
    path('logout/', views.app_distribution_logout, name='logout'),
    path('build/<uuid:build_id>/', views.app_build_detail, name='build_detail'),
]
