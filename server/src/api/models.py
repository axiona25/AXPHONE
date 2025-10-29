from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
from django.conf import settings
from datetime import timedelta
from cryptography.fernet import Fernet
import secrets
import string
import base64
import hashlib
import uuid


class AuthToken(models.Model):
    """Token di autenticazione personalizzato con scadenza e cifratura"""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='auth_tokens')
    encrypted_key = models.TextField(unique=True)  # Token cifrato
    created = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_active = models.BooleanField(default=True)
    
    class Meta:
        db_table = 'api_authtoken'
        verbose_name = 'Auth Token'
        verbose_name_plural = 'Auth Tokens'
    
    def save(self, *args, **kwargs):
        if not self.encrypted_key:
            self.encrypted_key = self.generate_encrypted_key()
        if not self.expires_at:
            # CORREZIONE: Token senza scadenza (valido per 10 anni)
            self.expires_at = timezone.now() + timedelta(days=3650)
        super().save(*args, **kwargs)
    
    def generate_encrypted_key(self):
        """Genera un token cifrato sicuro"""
        # Genera una chiave casuale di 32 byte
        raw_token = secrets.token_bytes(32)
        
        # Crea un hash del token per identificazione univoca
        token_hash = hashlib.sha256(raw_token).digest()
        
        # Combina token + timestamp + user_id per unicità
        timestamp = str(int(timezone.now().timestamp())).encode()
        user_id = str(self.user.id).encode() if self.user else b'0'
        
        # Crea payload da cifrare
        payload = raw_token + b'|' + timestamp + b'|' + user_id
        
        # Cifra il payload
        encrypted_payload = self._encrypt_data(payload)
        
        # Codifica in base64 per il database
        return base64.b64encode(encrypted_payload).decode()
    
    def _encrypt_data(self, data):
        """Cifra i dati usando Fernet"""
        # Usa la SECRET_KEY di Django per generare la chiave di cifratura
        key = hashlib.sha256(settings.SECRET_KEY.encode()).digest()
        fernet_key = base64.urlsafe_b64encode(key)
        fernet = Fernet(fernet_key)
        return fernet.encrypt(data)
    
    def _decrypt_data(self, encrypted_data):
        """Decifra i dati usando Fernet"""
        try:
            key = hashlib.sha256(settings.SECRET_KEY.encode()).digest()
            fernet_key = base64.urlsafe_b64encode(key)
            fernet = Fernet(fernet_key)
            return fernet.decrypt(encrypted_data)
        except Exception:
            return None
    
    def get_token(self):
        """Ottieni il token decifrato per l'uso nelle API"""
        try:
            encrypted_data = base64.b64decode(self.encrypted_key.encode())
            decrypted_payload = self._decrypt_data(encrypted_data)
            
            if decrypted_payload:
                parts = decrypted_payload.split(b'|')
                if len(parts) == 3:
                    # Restituisci solo il token raw per l'autenticazione
                    return parts[0].hex()
        except Exception:
            pass
        return None
    
    def get_decrypted_token(self):
        """Ottieni il token decifrato per verifiche"""
        try:
            encrypted_data = base64.b64decode(self.encrypted_key.encode())
            decrypted_payload = self._decrypt_data(encrypted_data)
            
            if decrypted_payload:
                parts = decrypted_payload.split(b'|')
                if len(parts) == 3:
                    return {
                        'token': parts[0],
                        'timestamp': parts[1].decode(),
                        'user_id': parts[2].decode()
                    }
        except Exception:
            pass
        return None
    
    def verify_token_integrity(self):
        """Verifica l'integrità del token"""
        decrypted = self.get_decrypted_token()
        if not decrypted:
            return False
        
        # Verifica che il user_id corrisponda
        if decrypted['user_id'] != str(self.user.id):
            return False
        
        # Verifica che il timestamp non sia troppo vecchio (max 25 ore)
        try:
            token_time = int(decrypted['timestamp'])
            current_time = int(timezone.now().timestamp())
            if current_time - token_time > 25 * 3600:  # 25 ore
                return False
        except (ValueError, TypeError):
            return False
        
        return True
    
    def is_expired(self):
        """Verifica se il token è scaduto"""
        return timezone.now() > self.expires_at
    
    def is_valid(self):
        """Verifica se il token è valido (attivo, non scaduto e integro)"""
        return (self.is_active and 
                not self.is_expired() and 
                self.verify_token_integrity())
    
    def __str__(self):
        return f"Token for {self.user.username} (expires: {self.expires_at})"


class Chat(models.Model):
    """Modello per le chat tra utenti"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    is_group = models.BooleanField(default=False)
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='created_chats')
    participants = models.ManyToManyField(User, related_name='chats')
    last_message = models.TextField(blank=True, null=True)
    last_message_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(default=True)
    
    # NUOVO: Sistema di eliminazione con gestazione
    deleted_by_users = models.ManyToManyField(User, blank=True, related_name='deleted_chats', 
        help_text="Utenti che hanno eliminato questa chat")
    deletion_requested_by = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL,
        related_name='requested_chat_deletions', help_text="Utente che ha richiesto l'eliminazione")
    deletion_requested_at = models.DateTimeField(null=True, blank=True,
        help_text="Quando è stata richiesta l'eliminazione")
    gestation_expires_at = models.DateTimeField(null=True, blank=True,
        help_text="Quando scade il periodo di gestazione (7 giorni)")
    is_in_gestation = models.BooleanField(default=False,
        help_text="True se la chat è in periodo di gestazione (sola lettura)")
    pending_deletion_notification_sent = models.BooleanField(default=False,
        help_text="True se la notifica di eliminazione è stata inviata")
    gestation_notification_shown = models.BooleanField(default=False,
        help_text="True se la notifica di gestazione è già stata mostrata all'utente")
    
    class Meta:
        ordering = ['-last_message_at', '-created_at']
        indexes = [
            models.Index(fields=['created_by']),
            models.Index(fields=['last_message_at']),
            models.Index(fields=['is_active']),
        ]
    
    def __str__(self):
        return f"Chat: {self.name} ({'Group' if self.is_group else 'Private'})"
    
    def is_deleted_for_user(self, user):
        """Verifica se la chat è eliminata per un utente specifico"""
        return self.deleted_by_users.filter(id=user.id).exists()
    
    def get_other_participant(self, current_user):
        """Ottiene l'altro partecipante in una chat privata"""
        if self.is_group:
            return None
        participants = self.participants.exclude(id=current_user.id)
        return participants.first() if participants.exists() else None
    
    def start_gestation_period(self, requesting_user):
        """Avvia il periodo di gestazione di 7 giorni"""
        from django.utils import timezone
        from datetime import timedelta
        
        self.deletion_requested_by = requesting_user
        self.deletion_requested_at = timezone.now()
        self.gestation_expires_at = timezone.now() + timedelta(days=7)
        self.is_in_gestation = True
        self.pending_deletion_notification_sent = False
        self.save()
    
    def is_gestation_expired(self):
        """Verifica se il periodo di gestazione è scaduto"""
        if not self.is_in_gestation or not self.gestation_expires_at:
            return False
        from django.utils import timezone
        return timezone.now() > self.gestation_expires_at
    
    def complete_deletion(self):
        """Completa l'eliminazione definitiva della chat"""
        # Elimina tutti i messaggi associati
        self.messages.all().delete()
        # Elimina la chat stessa
        self.delete()


class ChatMessage(models.Model):
    """Modello per i messaggi nelle chat"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    chat = models.ForeignKey(Chat, on_delete=models.CASCADE, related_name='messages')
    sender = models.ForeignKey(User, on_delete=models.CASCADE, related_name='sent_messages')
    content = models.TextField()
    message_type = models.CharField(max_length=20, choices=[
        ('text', 'Text'),
        ('image', 'Image'),
        ('video', 'Video'),
        ('audio', 'Audio'),
        ('file', 'File'),
        ('contact', 'Contact'),
        ('location', 'Location'),
    ], default='text')
    metadata = models.JSONField(null=True, blank=True, help_text="Metadati del messaggio (URL immagine, caption, etc.)")
    is_read = models.BooleanField(default=False)
    # read_at = models.DateTimeField(null=True, blank=True)  # Temporaneamente commentato
    deleted_for_users = models.ManyToManyField(User, blank=True, help_text="Utenti che hanno eliminato questo messaggio (solo per loro)")
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['created_at']
        indexes = [
            models.Index(fields=['chat', 'created_at']),
            models.Index(fields=['sender']),
            models.Index(fields=['is_read']),
        ]
    
    def __str__(self):
        return f"Message from {self.sender.username} in {self.chat.name}"


class PasswordResetToken(models.Model):
    """Token sicuro per il reset password con scadenza"""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='password_reset_tokens')
    token_hash = models.CharField(max_length=64, unique=True)  # Hash SHA256 del token
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)
    
    class Meta:
        db_table = 'api_passwordresettoken'
        verbose_name = 'Password Reset Token'
        verbose_name_plural = 'Password Reset Tokens'
        indexes = [
            models.Index(fields=['token_hash']),
            models.Index(fields=['expires_at']),
            models.Index(fields=['is_used']),
        ]
    
    def __str__(self):
        return f"Reset token for {self.user.email} - {'Used' if self.is_used else 'Active'}"
    
    def is_expired(self):
        """Verifica se il token è scaduto"""
        return timezone.now() > self.expires_at
    
    def is_valid(self):
        """Verifica se il token è valido (non scaduto e non usato)"""
        return not self.is_used and not self.is_expired()


class UserStatus(models.Model):
    """Modello per tracciare lo stato online/offline degli utenti"""
    STATUS_CHOICES = [
        ('online', 'Online'),
        ('offline', 'Offline'),
        ('unreachable', 'Unreachable'),
    ]
    
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='status_info')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='offline')
    is_logged_in = models.BooleanField(default=False)
    has_connection = models.BooleanField(default=False)
    last_seen = models.DateTimeField(default=timezone.now)
    last_activity = models.DateTimeField(default=timezone.now)
    session_token = models.CharField(max_length=255, blank=True, null=True)
    # E2EE: Chiave pubblica Diffie-Hellman dell'utente per cifratura end-to-end
    e2e_public_key = models.TextField(blank=True, null=True, help_text="Chiave pubblica Diffie-Hellman per E2EE")
    # E2EE: Configurazione e controlli admin
    e2e_enabled = models.BooleanField(default=True, help_text="E2EE abilitato per questo utente (default: True)")
    e2e_force_disabled = models.BooleanField(default=False, help_text="Admin ha forzato disabilitazione E2EE per questo utente")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'api_userstatus'
        verbose_name = 'User Status'
        verbose_name_plural = 'User Statuses'
        indexes = [
            models.Index(fields=['status']),
            models.Index(fields=['is_logged_in']),
            models.Index(fields=['last_seen']),
            models.Index(fields=['session_token']),
        ]
    
    def __str__(self):
        return f"{self.user.username} - {self.status}"
    
    def update_status(self, new_status=None, has_connection=None, token=None):
        """Aggiorna lo stato dell'utente"""
        now = timezone.now()
        
        if new_status:
            self.status = new_status
        if has_connection is not None:
            self.has_connection = has_connection
        if token:
            self.session_token = token
            
        self.last_activity = now
        self.updated_at = now
        
        # Determina is_logged_in basato su token valido
        if token:
            self.is_logged_in = True
            self.last_seen = now
        elif new_status == 'offline':
            self.is_logged_in = False
            
        self.save()
        
    def set_online(self, token):
        """Imposta utente online"""
        self.update_status('online', True, token)
        
    def set_offline(self):
        """Imposta utente offline"""
        self.update_status('offline', False, None)
        
    def set_unreachable(self):
        """Imposta utente irraggiungibile"""
        self.update_status('unreachable', False, self.session_token)
        
    def is_active_session(self):
        """Verifica se la sessione è ancora attiva"""
        if not self.session_token or not self.is_logged_in:
            return False
            
        # Verifica se il token esiste ancora
        try:
            from rest_framework.authtoken.models import Token
            Token.objects.get(key=self.session_token)
            return True
        except Token.DoesNotExist:
            return False


class Call(models.Model):
    """Modello per le chiamate"""
    CALL_TYPE_CHOICES = [
        ('audio', 'Audio'),
        ('video', 'Video'),
    ]
    
    CALL_DIRECTION_CHOICES = [
        ('incoming', 'Incoming'),
        ('outgoing', 'Outgoing'),
        ('missed', 'Missed'),
    ]
    
    CALL_STATUS_CHOICES = [
        ('completed', 'Completed'),
        ('missed', 'Missed'),
        ('declined', 'Declined'),
        ('cancelled', 'Cancelled'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    session_id = models.CharField(max_length=100, unique=True, null=True, blank=True)  # Per WebRTC
    caller = models.ForeignKey(User, on_delete=models.CASCADE, related_name='outgoing_calls')
    callee = models.ForeignKey(User, on_delete=models.CASCADE, related_name='incoming_calls')
    call_type = models.CharField(max_length=10, choices=CALL_TYPE_CHOICES, default='audio')
    direction = models.CharField(max_length=10, choices=CALL_DIRECTION_CHOICES, default='outgoing')
    status = models.CharField(max_length=10, choices=[
        ('ringing', 'Ringing'),
        ('answered', 'Answered'),
        ('completed', 'Completed'),
        ('missed', 'Missed'),
        ('declined', 'Declined'),
        ('cancelled', 'Cancelled'),
        ('seen', 'Seen'),
    ], default='completed')
    duration = models.DurationField(default=timedelta(seconds=0))
    timestamp = models.DateTimeField(default=timezone.now)
    phone_number = models.CharField(max_length=20, blank=True, null=True)
    is_encrypted = models.BooleanField(default=True)  # E2E encryption enabled by default
    ended_at = models.DateTimeField(null=True, blank=True)  # When call ended
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'api_call'
        verbose_name = 'Call'
        verbose_name_plural = 'Calls'
        ordering = ['-timestamp']
    
    def __str__(self):
        return f"{self.caller.username} -> {self.callee.username} ({self.call_type})"
    
    def to_dict(self):
        """Converte il modello in dizionario per l'API"""
        return {
            'id': str(self.id),
            'contactName': self.callee.get_full_name() or self.callee.username,
            'contactAvatar': '',  # Per ora vuoto, da implementare
            'contactId': str(self.callee.id),
            'callerId': str(self.caller.id),
            'calleeId': str(self.callee.id),
            'timestamp': self.timestamp.isoformat(),
            'type': self.call_type,
            'direction': self.direction,
            'status': self.status,
            'duration': int(self.duration.total_seconds()),
            'phoneNumber': self.phone_number,
        }


# Modelli per SecureVOX Call Server Integration
class WebRTCCall(models.Model):
    """Modello per chiamate WebRTC gestite da SecureVOX Call Server"""
    
    CALL_TYPE_CHOICES = [
        ('audio', 'Audio'),
        ('video', 'Video'),
    ]
    
    STATUS_CHOICES = [
        ('ringing', 'Ringing'),
        ('answered', 'Answered'),
        ('connected', 'Connected'),
        ('ended', 'Ended'),
        ('rejected', 'Rejected'),
        ('missed', 'Missed'),
        ('failed', 'Failed'),
    ]
    
    session_id = models.CharField(max_length=255, unique=True, db_index=True)
    caller = models.ForeignKey(User, on_delete=models.CASCADE, related_name='webrtc_calls_made')
    callee = models.ForeignKey(User, on_delete=models.CASCADE, related_name='webrtc_calls_received')
    call_type = models.CharField(max_length=10, choices=CALL_TYPE_CHOICES, default='audio')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='ringing')
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    answered_at = models.DateTimeField(null=True, blank=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    
    # Metadati
    end_reason = models.CharField(max_length=100, blank=True, null=True)
    encrypted_payload = models.TextField(blank=True, null=True)
    
    class Meta:
        db_table = 'api_webrtc_call'
        verbose_name = 'WebRTC Call'
        verbose_name_plural = 'WebRTC Calls'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"WebRTC Call {self.session_id}: {self.caller} -> {self.callee} ({self.status})"
    
    @property
    def duration(self):
        """Calcola durata chiamata"""
        if self.answered_at and self.ended_at:
            return self.ended_at - self.answered_at
        elif self.answered_at:
            return timezone.now() - self.answered_at
        return timedelta(0)
    
    def to_dict(self):
        """Converte in dizionario per API"""
        return {
            'id': self.id,
            'session_id': self.session_id,
            'caller': {
                'id': str(self.caller.id),
                'name': self.caller.get_full_name() or self.caller.username,
                'email': self.caller.email,
            },
            'callee': {
                'id': str(self.callee.id),
                'name': self.callee.get_full_name() or self.callee.username,
                'email': self.callee.email,
            },
            'call_type': self.call_type,
            'status': self.status,
            'created_at': self.created_at.isoformat(),
            'answered_at': self.answered_at.isoformat() if self.answered_at else None,
            'ended_at': self.ended_at.isoformat() if self.ended_at else None,
            'duration': int(self.duration.total_seconds()),
            'end_reason': self.end_reason,
        }


class CallParticipant(models.Model):
    """Partecipanti a una chiamata WebRTC"""
    
    call = models.ForeignKey(WebRTCCall, on_delete=models.CASCADE, related_name='participants')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='call_participations')
    
    # Timestamps
    joined_at = models.DateTimeField(auto_now_add=True)
    left_at = models.DateTimeField(null=True, blank=True)
    
    # Stati partecipante
    audio_muted = models.BooleanField(default=False)
    video_muted = models.BooleanField(default=True)  # Default audio-only
    
    class Meta:
        db_table = 'api_call_participant'
        verbose_name = 'Call Participant'
        verbose_name_plural = 'Call Participants'
        unique_together = ['call', 'user']
    
    def __str__(self):
        return f"{self.user} in {self.call.session_id}"
    
    @property
    def participation_duration(self):
        """Calcola durata partecipazione"""
        end_time = self.left_at or timezone.now()
        return end_time - self.joined_at
    
    def to_dict(self):
        """Converte in dizionario per API"""
        return {
            'user_id': str(self.user.id),
            'user_name': self.user.get_full_name() or self.user.username,
            'joined_at': self.joined_at.isoformat(),
            'left_at': self.left_at.isoformat() if self.left_at else None,
            'audio_muted': self.audio_muted,
            'video_muted': self.video_muted,
            'duration': int(self.participation_duration.total_seconds()),
        }
