from django.contrib import admin
from django.utils.html import format_html
from django.urls import reverse
from django.utils.safestring import mark_safe
from .models import AppBuild, AppDownload, AppFeedback


@admin.register(AppBuild)
class AppBuildAdmin(admin.ModelAdmin):
    list_display = [
        'name', 'platform', 'version', 'build_number', 'status', 
        'is_active', 'is_beta', 'download_count', 'uploaded_by', 'created_at'
    ]
    list_filter = ['platform', 'status', 'is_active', 'is_beta', 'created_at']
    search_fields = ['name', 'version', 'build_number', 'bundle_id']
    readonly_fields = ['id', 'created_at', 'updated_at', 'download_count', 'file_size_display', 'install_link']
    
    fieldsets = [
        ('Informazioni Base', {
            'fields': ['name', 'platform', 'version', 'build_number', 'bundle_id']
        }),
        ('File', {
            'fields': ['app_file', 'icon', 'file_size_display']
        }),
        ('Descrizione', {
            'fields': ['description', 'release_notes', 'min_os_version']
        }),
        ('Stato e Controllo', {
            'fields': ['status', 'is_active', 'is_beta', 'uploaded_by', 'allowed_users']
        }),
        ('Statistiche', {
            'fields': ['download_count', 'install_link'],
            'classes': ['collapse']
        }),
        ('Timestamp', {
            'fields': ['id', 'created_at', 'updated_at'],
            'classes': ['collapse']
        })
    ]
    
    filter_horizontal = ['allowed_users']
    
    def file_size_display(self, obj):
        """Mostra la dimensione del file in formato leggibile"""
        return f"{obj.file_size_mb} MB"
    file_size_display.short_description = "Dimensione File"
    
    def install_link(self, obj):
        """Mostra il link di installazione per iOS"""
        if obj.platform == 'ios' and obj.install_url:
            return format_html(
                '<a href="{}" class="button">Link Installazione iOS</a>',
                obj.install_url
            )
        return "N/A per Android"
    install_link.short_description = "Link Installazione"
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related('uploaded_by')
    
    def save_model(self, request, obj, form, change):
        if not change:  # Se è una nuova build
            obj.uploaded_by = request.user
        super().save_model(request, obj, form, change)


@admin.register(AppDownload)
class AppDownloadAdmin(admin.ModelAdmin):
    list_display = [
        'app_build_info', 'user', 'ip_address', 'downloaded_at'
    ]
    list_filter = ['app_build__platform', 'downloaded_at']
    search_fields = ['app_build__name', 'user__username', 'ip_address']
    readonly_fields = ['id', 'app_build', 'user', 'ip_address', 'user_agent', 'device_info', 'downloaded_at']
    
    def app_build_info(self, obj):
        """Mostra informazioni sulla build"""
        return f"{obj.app_build.name} v{obj.app_build.version} ({obj.app_build.get_platform_display()})"
    app_build_info.short_description = "App Build"
    
    def has_add_permission(self, request):
        return False  # Non permettere la creazione manuale
    
    def has_change_permission(self, request, obj=None):
        return False  # Non permettere la modifica
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related('app_build', 'user')


@admin.register(AppFeedback)
class AppFeedbackAdmin(admin.ModelAdmin):
    list_display = [
        'app_build_info', 'user', 'rating_display', 'comment_preview', 'created_at'
    ]
    list_filter = ['rating', 'app_build__platform', 'created_at']
    search_fields = ['app_build__name', 'user__username', 'comment']
    readonly_fields = ['id', 'app_build', 'user', 'created_at']
    
    def app_build_info(self, obj):
        """Mostra informazioni sulla build"""
        return f"{obj.app_build.name} v{obj.app_build.version}"
    app_build_info.short_description = "App Build"
    
    def rating_display(self, obj):
        """Mostra il rating con stelle"""
        stars = '⭐' * obj.rating + '☆' * (5 - obj.rating)
        return f"{stars} ({obj.rating}/5)"
    rating_display.short_description = "Valutazione"
    
    def comment_preview(self, obj):
        """Mostra un'anteprima del commento"""
        if obj.comment:
            return obj.comment[:50] + '...' if len(obj.comment) > 50 else obj.comment
        return "Nessun commento"
    comment_preview.short_description = "Commento"
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related('app_build', 'user')


# Personalizza l'header dell'admin
admin.site.site_header = "SecureVOX App Distribution Admin"
admin.site.site_title = "App Distribution"
admin.site.index_title = "Gestione Distribuzione App"
