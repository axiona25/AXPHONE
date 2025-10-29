from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
import uuid


class RemoteWipeCommand(models.Model):
    """Comandi di remote wipe per dispositivi"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey('crypto.Device', on_delete=models.CASCADE, related_name='wipe_commands')
    initiated_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='wipe_commands')
    reason = models.CharField(max_length=255, blank=True)
    status = models.CharField(max_length=20, choices=[
        ('pending', 'Pending'),
        ('sent', 'Sent'),
        ('acknowledged', 'Acknowledged'),
        ('completed', 'Completed'),
        ('failed', 'Failed'),
    ], default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    sent_at = models.DateTimeField(null=True, blank=True)
    acknowledged_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        indexes = [
            models.Index(fields=['device', 'status']),
            models.Index(fields=['initiated_by']),
            models.Index(fields=['created_at']),
        ]


class DeviceAuditLog(models.Model):
    """Log di audit per dispositivi"""
    device = models.ForeignKey('crypto.Device', on_delete=models.CASCADE, related_name='audit_logs')
    action = models.CharField(max_length=50, choices=[
        ('register', 'Device Registered'),
        ('activate', 'Device Activated'),
        ('deactivate', 'Device Deactivated'),
        ('compromise_detected', 'Compromise Detected'),
        ('key_rotation', 'Key Rotation'),
        ('remote_wipe', 'Remote Wipe'),
        ('logout', 'User Logout'),
    ])
    details = models.JSONField(null=True, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        indexes = [
            models.Index(fields=['device', 'action']),
            models.Index(fields=['created_at']),
        ]
