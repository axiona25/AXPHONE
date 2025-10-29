import os
import uuid
from django.db import models
from django.contrib.auth.models import User
from django.core.validators import RegexValidator
from django.utils import timezone


class AppBuild(models.Model):
    """Modello per rappresentare una build dell'app (iOS o Android)"""
    
    PLATFORM_CHOICES = [
        ('ios', 'iOS'),
        ('android', 'Android'),
    ]
    
    STATUS_CHOICES = [
        ('uploading', 'Uploading'),
        ('processing', 'Processing'),
        ('ready', 'Ready'),
        ('failed', 'Failed'),
    ]
    
    # Identificatori
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200, help_text="Nome dell'app")
    platform = models.CharField(max_length=10, choices=PLATFORM_CHOICES)
    version = models.CharField(max_length=50, help_text="Versione dell'app (es. 1.0.0)")
    build_number = models.CharField(max_length=50, help_text="Build number (es. 123)")
    bundle_id = models.CharField(
        max_length=200,
        validators=[RegexValidator(
            regex=r'^[a-zA-Z0-9.-]+$',
            message='Bundle ID deve contenere solo lettere, numeri, punti e trattini'
        )]
    )
    
    # File
    app_file = models.FileField(
        upload_to='app_builds/',
        help_text="File .ipa per iOS o .apk/.aab per Android"
    )
    icon = models.ImageField(upload_to='app_icons/', null=True, blank=True)
    
    # Metadati
    description = models.TextField(blank=True, help_text="Descrizione delle modifiche")
    release_notes = models.TextField(blank=True, help_text="Note di rilascio")
    min_os_version = models.CharField(max_length=20, blank=True, help_text="Versione minima OS")
    
    # Stato e gestione
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='uploading')
    is_active = models.BooleanField(default=True, help_text="Build disponibile per il download")
    is_beta = models.BooleanField(default=True, help_text="Build beta o release")
    
    # Controllo accessi
    uploaded_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='uploaded_builds')
    allowed_users = models.ManyToManyField(
        User, 
        blank=True, 
        related_name='allowed_builds',
        help_text="Utenti autorizzati al download (lasciare vuoto per tutti)"
    )
    
    # Timestamp
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # Statistiche
    download_count = models.PositiveIntegerField(default=0)
    
    class Meta:
        ordering = ['-created_at']
        unique_together = ['platform', 'bundle_id', 'version', 'build_number']
    
    def __str__(self):
        return f"{self.name} v{self.version} ({self.build_number}) - {self.get_platform_display()}"
    
    @property
    def file_size(self):
        """Ritorna la dimensione del file in bytes"""
        try:
            return self.app_file.size
        except:
            return 0
    
    @property
    def file_size_mb(self):
        """Ritorna la dimensione del file in MB"""
        return round(self.file_size / (1024 * 1024), 2)
    
    @property
    def install_url(self):
        """Genera l'URL di installazione per iOS"""
        if self.platform == 'ios':
            return f"itms-services://?action=download-manifest&url=https://your-domain.com/api/app-distribution/manifest/{self.id}/"
        return None
    
    def can_download(self, user):
        """Verifica se l'utente può scaricare questa build"""
        if not self.is_active or self.status != 'ready':
            return False
        
        # Se non ci sono restrizioni, tutti possono scaricare
        if not self.allowed_users.exists():
            return True
        
        # Verifica se l'utente è nella lista degli autorizzati
        return self.allowed_users.filter(id=user.id).exists()


class AppDownload(models.Model):
    """Modello per tracciare i download delle app"""
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    app_build = models.ForeignKey(AppBuild, on_delete=models.CASCADE, related_name='downloads')
    user = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True)
    ip_address = models.GenericIPAddressField()
    user_agent = models.TextField(blank=True)
    device_info = models.JSONField(default=dict, blank=True)
    downloaded_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-downloaded_at']
    
    def __str__(self):
        user_info = self.user.username if self.user else self.ip_address
        return f"{self.app_build.name} downloaded by {user_info}"


class AppFeedback(models.Model):
    """Modello per feedback degli utenti sulle build"""
    
    RATING_CHOICES = [
        (1, '⭐'),
        (2, '⭐⭐'),
        (3, '⭐⭐⭐'),
        (4, '⭐⭐⭐⭐'),
        (5, '⭐⭐⭐⭐⭐'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    app_build = models.ForeignKey(AppBuild, on_delete=models.CASCADE, related_name='feedback')
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    rating = models.IntegerField(choices=RATING_CHOICES)
    comment = models.TextField(blank=True)
    device_info = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ['app_build', 'user']
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.app_build.name} - {self.rating}⭐ by {self.user.username}"
