from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
import uuid


class Tenant(models.Model):
    """Organizzazioni/tenant per multi-tenancy"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100)
    domain = models.CharField(max_length=100, unique=True)
    admin = models.ForeignKey(User, on_delete=models.CASCADE, related_name='admin_tenants')
    is_active = models.BooleanField(default=True)
    max_users = models.PositiveIntegerField(default=100)
    max_devices_per_user = models.PositiveIntegerField(default=5)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        indexes = [
            models.Index(fields=['domain']),
            models.Index(fields=['is_active']),
        ]


class UserProfile(models.Model):
    """Profilo esteso per utenti"""
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    tenant = models.ForeignKey(Tenant, on_delete=models.CASCADE, related_name='users')
    phone_number = models.CharField(max_length=20, blank=True)
    bio = models.TextField(blank=True, null=True)
    location = models.CharField(max_length=100, blank=True, null=True)
    date_of_birth = models.DateField(null=True, blank=True)
    avatar_url = models.TextField(blank=True, null=True)
    is_verified = models.BooleanField(default=False)
    last_activity = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        indexes = [
            models.Index(fields=['tenant', 'is_verified']),
            models.Index(fields=['last_activity']),
        ]


class AdminAction(models.Model):
    """Log delle azioni amministrative"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    admin = models.ForeignKey(User, on_delete=models.CASCADE, related_name='admin_actions')
    action_type = models.CharField(max_length=50, choices=[
        ('user_create', 'User Created'),
        ('user_deactivate', 'User Deactivated'),
        ('device_wipe', 'Device Wiped'),
        ('tenant_create', 'Tenant Created'),
        ('tenant_update', 'Tenant Updated'),
        ('key_rotation', 'Forced Key Rotation'),
    ])
    target_user = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True, related_name='admin_actions_received')
    target_device = models.ForeignKey('crypto.Device', on_delete=models.CASCADE, null=True, blank=True)
    details = models.JSONField(null=True, blank=True)
    ip_address = models.GenericIPAddressField()
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        indexes = [
            models.Index(fields=['admin', 'action_type']),
            models.Index(fields=['target_user']),
            models.Index(fields=['created_at']),
        ]


class UserGroup(models.Model):
    """Gruppi di utenti per organizzazione e gestione"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True, null=True)
    color = models.CharField(max_length=7, default='#667eea')  # Colore hex per UI
    tenant = models.ForeignKey(Tenant, on_delete=models.CASCADE, related_name='user_groups')
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='created_groups')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        unique_together = ['name', 'tenant']
        indexes = [
            models.Index(fields=['tenant', 'is_active']),
            models.Index(fields=['created_by']),
        ]
    
    def __str__(self):
        return f"{self.name} ({self.tenant.name})"


class UserGroupMembership(models.Model):
    """Appartenenza degli utenti ai gruppi"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='group_memberships')
    group = models.ForeignKey(UserGroup, on_delete=models.CASCADE, related_name='memberships')
    assigned_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='group_assignments')
    assigned_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)
    
    class Meta:
        unique_together = ['user', 'group']
        indexes = [
            models.Index(fields=['user', 'is_active']),
            models.Index(fields=['group', 'is_active']),
        ]
    
    def __str__(self):
        return f"{self.user.username} in {self.group.name}"
