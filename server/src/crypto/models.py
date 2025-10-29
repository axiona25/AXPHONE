from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
import uuid
import json


class Device(models.Model):
    """Modello per dispositivi utente con autenticazione basata su token"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='devices')
    device_name = models.CharField(max_length=100)
    device_type = models.CharField(max_length=20, choices=[
        ('android', 'Android'),
        ('ios', 'iOS'),
        ('web', 'Web'),
        ('desktop', 'Desktop'),
    ])
    fcm_token = models.CharField(max_length=255, blank=True, null=True)
    apns_token = models.CharField(max_length=255, blank=True, null=True)
    device_fingerprint = models.CharField(max_length=255, unique=True)
    is_active = models.BooleanField(default=True)
    last_seen = models.DateTimeField(default=timezone.now)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # Security flags
    is_rooted = models.BooleanField(default=False)
    is_jailbroken = models.BooleanField(default=False)
    is_compromised = models.BooleanField(default=False)
    
    class Meta:
        unique_together = ['user', 'device_fingerprint']
        indexes = [
            models.Index(fields=['user', 'is_active']),
            models.Index(fields=['device_fingerprint']),
        ]

    def __str__(self):
        return f"{self.user.username} - {self.device_name}"


class IdentityKey(models.Model):
    """Chiave di identità per protocollo Signal X3DH"""
    device = models.OneToOneField(Device, on_delete=models.CASCADE, related_name='identity_key')
    public_key = models.BinaryField()  # Chiave pubblica Ed25519
    private_key_encrypted = models.BinaryField()  # Chiave privata cifrata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        indexes = [
            models.Index(fields=['device']),
        ]


class SignedPreKey(models.Model):
    """Chiave pre-firmata per protocollo Signal X3DH"""
    device = models.ForeignKey(Device, on_delete=models.CASCADE, related_name='signed_prekeys')
    key_id = models.PositiveIntegerField()
    public_key = models.BinaryField()
    signature = models.BinaryField()
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    
    class Meta:
        unique_together = ['device', 'key_id']
        indexes = [
            models.Index(fields=['device', 'key_id']),
            models.Index(fields=['expires_at']),
        ]


class OneTimePreKey(models.Model):
    """Chiavi one-time per protocollo Signal X3DH"""
    device = models.ForeignKey(Device, on_delete=models.CASCADE, related_name='one_time_prekeys')
    key_id = models.PositiveIntegerField()
    public_key = models.BinaryField()
    created_at = models.DateTimeField(auto_now_add=True)
    used_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        unique_together = ['device', 'key_id']
        indexes = [
            models.Index(fields=['device', 'key_id']),
            models.Index(fields=['used_at']),
        ]


class Session(models.Model):
    """Sessione Double Ratchet tra due dispositivi"""
    device_a = models.ForeignKey(Device, on_delete=models.CASCADE, related_name='sessions_as_a')
    device_b = models.ForeignKey(Device, on_delete=models.CASCADE, related_name='sessions_as_b')
    session_data_encrypted = models.BinaryField()  # Dati sessione cifrati
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    last_message_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        unique_together = ['device_a', 'device_b']
        indexes = [
            models.Index(fields=['device_a', 'device_b']),
            models.Index(fields=['last_message_at']),
        ]


class Message(models.Model):
    """Messaggi cifrati (solo metadati, contenuto non memorizzato)"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    sender = models.ForeignKey(Device, on_delete=models.CASCADE, related_name='sent_messages')
    recipient = models.ForeignKey(Device, on_delete=models.CASCADE, related_name='received_messages')
    message_type = models.CharField(max_length=20, choices=[
        ('text', 'Text'),
        ('image', 'Image'),
        ('video', 'Video'),
        ('audio', 'Audio'),
        ('file', 'File'),
        ('call', 'Call'),
    ])
    encrypted_content_hash = models.CharField(max_length=64)  # SHA-256 del contenuto cifrato
    created_at = models.DateTimeField(auto_now_add=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    read_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        indexes = [
            models.Index(fields=['sender', 'recipient']),
            models.Index(fields=['created_at']),
            models.Index(fields=['delivered_at']),
        ]


class KeyRotationLog(models.Model):
    """Log delle rotazioni delle chiavi per audit"""
    device = models.ForeignKey(Device, on_delete=models.CASCADE, related_name='key_rotations')
    rotation_type = models.CharField(max_length=20, choices=[
        ('identity', 'Identity Key'),
        ('signed_prekey', 'Signed PreKey'),
        ('one_time_prekey', 'One-Time PreKey'),
        ('session', 'Session Key'),
    ])
    old_key_hash = models.CharField(max_length=64, null=True, blank=True)
    new_key_hash = models.CharField(max_length=64)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        indexes = [
            models.Index(fields=['device', 'rotation_type']),
            models.Index(fields=['created_at']),
        ]
