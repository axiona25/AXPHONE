import os
import json
from django.http import HttpResponse, JsonResponse, Http404
from django.shortcuts import get_object_or_404, render, redirect
from django.template.loader import render_to_string
from django.utils import timezone
from django.contrib.auth.models import User
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.db import models
from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from .models import AppBuild, AppDownload, AppFeedback
from .serializers import (
    AppBuildSerializer, AppBuildCreateSerializer,
    AppDownloadSerializer, AppFeedbackSerializer, AppFeedbackCreateSerializer
)


def get_client_ip(request):
    """Ottiene l'IP del client"""
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip


def app_distribution_login(request):
    """Pagina di login per App Distribution"""
    if request.user.is_authenticated:
        return redirect('app_distribution:index')
    
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        user = authenticate(request, username=username, password=password)
        
        if user is not None:
            login(request, user)
            return redirect('app_distribution:index')
        else:
            from django.contrib import messages
            messages.error(request, 'Username o password non corretti')
    
    return render(request, 'app_distribution/login.html')


def app_distribution_logout(request):
    """Logout per App Distribution"""
    logout(request)
    return redirect('app_distribution:index')


class AppBuildViewSet(viewsets.ModelViewSet):
    """ViewSet per gestire le build delle app"""
    
    queryset = AppBuild.objects.all()
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]
    
    def get_serializer_class(self):
        if self.action == 'create':
            return AppBuildCreateSerializer
        return AppBuildSerializer
    
    def get_queryset(self):
        """Filtra le build in base ai permessi dell'utente"""
        queryset = AppBuild.objects.all()
        
        # Filtra per piattaforma se specificata
        platform = self.request.query_params.get('platform')
        if platform:
            queryset = queryset.filter(platform=platform)
        
        # Filtra per stato se specificato
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        # Filtra per build attive se specificato
        is_active = self.request.query_params.get('is_active')
        if is_active is not None:
            queryset = queryset.filter(is_active=is_active.lower() == 'true')
        
        return queryset
    
    def perform_create(self, serializer):
        """Imposta l'utente che ha caricato la build"""
        serializer.save(uploaded_by=self.request.user)
    
    @action(detail=True, methods=['post'])
    def download(self, request, pk=None):
        """Endpoint per scaricare una build"""
        app_build = self.get_object()
        
        # Verifica se l'utente può scaricare
        if not app_build.can_download(request.user):
            return Response(
                {'error': 'Non hai i permessi per scaricare questa build'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Registra il download
        AppDownload.objects.create(
            app_build=app_build,
            user=request.user,
            ip_address=get_client_ip(request),
            user_agent=request.META.get('HTTP_USER_AGENT', ''),
            device_info=request.data.get('device_info', {})
        )
        
        # Incrementa il contatore di download
        app_build.download_count += 1
        app_build.save(update_fields=['download_count'])
        
        # Ritorna l'URL del file
        return Response({
            'download_url': request.build_absolute_uri(app_build.app_file.url),
            'filename': os.path.basename(app_build.app_file.name),
            'size_mb': app_build.file_size_mb
        })
    
    @action(detail=True, methods=['get'])
    def manifest(self, request, pk=None):
        """Genera il manifest per l'installazione iOS"""
        app_build = self.get_object()
        
        if app_build.platform != 'ios':
            return Response(
                {'error': 'Il manifest è disponibile solo per le app iOS'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if not app_build.can_download(request.user):
            return Response(
                {'error': 'Non hai i permessi per installare questa build'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Genera il manifest plist per iOS
        manifest_data = {
            'items': [{
                'assets': [{
                    'kind': 'software-package',
                    'url': request.build_absolute_uri(app_build.app_file.url)
                }],
                'metadata': {
                    'bundle-identifier': app_build.bundle_id,
                    'bundle-version': app_build.version,
                    'kind': 'software',
                    'title': app_build.name
                }
            }]
        }
        
        # Se c'è un'icona, aggiungila al manifest
        if app_build.icon:
            manifest_data['items'][0]['assets'].append({
                'kind': 'display-image',
                'needs-shine': True,
                'url': request.build_absolute_uri(app_build.icon.url)
            })
        
        # Genera il plist XML
        plist_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>items</key>
    <array>
        <dict>
            <key>assets</key>
            <array>
                <dict>
                    <key>kind</key>
                    <string>software-package</string>
                    <key>url</key>
                    <string>{request.build_absolute_uri(app_build.app_file.url)}</string>
                </dict>
            </array>
            <key>metadata</key>
            <dict>
                <key>bundle-identifier</key>
                <string>{app_build.bundle_id}</string>
                <key>bundle-version</key>
                <string>{app_build.version}</string>
                <key>kind</key>
                <string>software</string>
                <key>title</key>
                <string>{app_build.name}</string>
            </dict>
        </dict>
    </array>
</dict>
</plist>'''
        
        response = HttpResponse(plist_content, content_type='application/x-plist')
        response['Content-Disposition'] = f'attachment; filename="{app_build.name}-manifest.plist"'
        return response
    
    @action(detail=True, methods=['post'])
    def toggle_active(self, request, pk=None):
        """Attiva/disattiva una build"""
        app_build = self.get_object()
        
        # Solo il proprietario o admin può modificare lo stato
        if app_build.uploaded_by != request.user and not request.user.is_staff:
            return Response(
                {'error': 'Non hai i permessi per modificare questa build'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        app_build.is_active = not app_build.is_active
        app_build.save(update_fields=['is_active'])
        
        return Response({
            'is_active': app_build.is_active,
            'message': f"Build {'attivata' if app_build.is_active else 'disattivata'}"
        })
    
    @action(detail=True, methods=['get'])
    def stats(self, request, pk=None):
        """Statistiche di una build"""
        app_build = self.get_object()
        
        # Solo il proprietario o admin può vedere le statistiche
        if app_build.uploaded_by != request.user and not request.user.is_staff:
            return Response(
                {'error': 'Non hai i permessi per vedere le statistiche'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Calcola statistiche
        downloads = AppDownload.objects.filter(app_build=app_build)
        feedback = AppFeedback.objects.filter(app_build=app_build)
        
        return Response({
            'total_downloads': downloads.count(),
            'unique_users': downloads.values('user').distinct().count(),
            'feedback_count': feedback.count(),
            'average_rating': feedback.aggregate(
                avg_rating=models.Avg('rating')
            )['avg_rating'] or 0,
            'downloads_by_day': downloads.extra(
                select={'day': 'date(downloaded_at)'}
            ).values('day').annotate(count=models.Count('id')).order_by('day')
        })


class AppFeedbackViewSet(viewsets.ModelViewSet):
    """ViewSet per gestire i feedback delle app"""
    
    queryset = AppFeedback.objects.all()
    permission_classes = [permissions.IsAuthenticated]
    
    def get_serializer_class(self):
        if self.action == 'create':
            return AppFeedbackCreateSerializer
        return AppFeedbackSerializer
    
    def get_queryset(self):
        """Filtra i feedback per build se specificata"""
        queryset = AppFeedback.objects.all()
        
        app_build_id = self.request.query_params.get('app_build')
        if app_build_id:
            queryset = queryset.filter(app_build_id=app_build_id)
        
        return queryset
    
    def perform_create(self, serializer):
        """Imposta l'utente che ha lasciato il feedback"""
        serializer.save(user=self.request.user)


# View per l'interfaccia web
@login_required(login_url='app_distribution:login')
def app_distribution_index(request):
    """Pagina principale per la distribuzione delle app"""
    builds = AppBuild.objects.filter(is_active=True, status='ready').order_by('-created_at')
    
    # Filtra per piattaforma se specificata
    platform = request.GET.get('platform')
    if platform:
        builds = builds.filter(platform=platform)
    
    context = {
        'builds': builds,
        'platform_filter': platform,
        'total_builds': builds.count(),
        'ios_builds': builds.filter(platform='ios').count(),
        'android_builds': builds.filter(platform='android').count(),
    }
    
    return render(request, 'app_distribution/index.html', context)


def app_build_detail(request, build_id):
    """Pagina di dettaglio di una build"""
    app_build = get_object_or_404(AppBuild, id=build_id, is_active=True, status='ready')
    
    # Verifica permessi di download
    can_download = app_build.can_download(request.user) if request.user.is_authenticated else False
    
    # Ottieni feedback
    feedback = AppFeedback.objects.filter(app_build=app_build).order_by('-created_at')[:10]
    
    context = {
        'app_build': app_build,
        'can_download': can_download,
        'feedback': feedback,
        'user_feedback': None
    }
    
    # Se l'utente è autenticato, verifica se ha già lasciato feedback
    if request.user.is_authenticated:
        try:
            context['user_feedback'] = AppFeedback.objects.get(
                app_build=app_build, user=request.user
            )
        except AppFeedback.DoesNotExist:
            pass
    
    return render(request, 'app_distribution/build_detail.html', context)
