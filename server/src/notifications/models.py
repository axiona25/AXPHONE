from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
import uuid
import json


class NotificationQueue(models.Model):
    """Coda notifiche push cifrate"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    device = models.ForeignKey('crypto.Device', on_delete=models.CASCADE, related_name='notifications')
    notification_type = models.CharField(max_length=20, choices=[
        ('message', 'Message'),
        ('call', 'Call'),
        ('remote_wipe', 'Remote Wipe'),
        ('key_rotation', 'Key Rotation'),
    ])
    encrypted_payload = models.BinaryField()  # Payload cifrato con chiave di sessione
    priority = models.CharField(max_length=10, choices=[
        ('low', 'Low'),
        ('normal', 'Normal'),
        ('high', 'High'),
        ('urgent', 'Urgent'),
    ], default='normal')
    created_at = models.DateTimeField(auto_now_add=True)
    scheduled_at = models.DateTimeField(default=timezone.now)
    sent_at = models.DateTimeField(null=True, blank=True)
    failed_at = models.DateTimeField(null=True, blank=True)
    retry_count = models.PositiveIntegerField(default=0)
    max_retries = models.PositiveIntegerField(default=3)
    
    class Meta:
        indexes = [
            models.Index(fields=['device', 'scheduled_at']),
            models.Index(fields=['notification_type']),
            models.Index(fields=['sent_at']),
        ]


class NotificationLog(models.Model):
    """Log delle notifiche inviate per audit"""
    notification = models.OneToOneField(NotificationQueue, on_delete=models.CASCADE, related_name='log')
    fcm_message_id = models.CharField(max_length=255, null=True, blank=True)
    apns_message_id = models.CharField(max_length=255, null=True, blank=True)
    response_status = models.CharField(max_length=10, choices=[
        ('success', 'Success'),
        ('failed', 'Failed'),
        ('retry', 'Retry'),
    ])
    response_data = models.JSONField(null=True, blank=True)
    sent_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        indexes = [
            models.Index(fields=['response_status']),
            models.Index(fields=['sent_at']),
        ]
