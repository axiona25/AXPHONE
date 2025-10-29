from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.utils.decorators import method_decorator
from django.views import View
from django.utils import timezone
from datetime import timedelta
from django.db import models
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.contrib.auth.models import User
from crypto.models import Device, IdentityKey, SignedPreKey, OneTimePreKey, Session
from notifications.models import NotificationQueue
from devices.models import RemoteWipeCommand, DeviceAuditLog
from .models import Chat, ChatMessage, Call
from .webrtc_service import webrtc_service
import json
import logging
import base64

logger = logging.getLogger('securevox')


def _send_incoming_call_notification(call_record):
    """
    Invia notifica di chiamata in arrivo al destinatario
    
    Args:
        call_record: Record della chiamata dal database
    """
    try:
        logger.info(f"📞 Invio notifica chiamata in arrivo a {call_record.callee.username}")
        
        # Payload notifica per SecureVOX Notify (formato corretto)
        notification_payload = {
            'recipient_id': str(call_record.callee.id),
            'sender_id': str(call_record.caller.id),
            'notification_type': 'call' if call_record.call_type == 'audio' else 'video_call',
            'title': f'Chiamata da {call_record.caller.first_name or call_record.caller.username}',
            'body': f'Chiamata {call_record.call_type} in arrivo',
            'data': {
                'session_id': call_record.session_id,
                'caller_id': str(call_record.caller.id),
                'caller_name': f"{call_record.caller.first_name} {call_record.caller.last_name}".strip() or call_record.caller.username,
                'call_type': call_record.call_type,
                'is_encrypted': call_record.is_encrypted,
                'action': 'incoming_call'
            },
            'timestamp': call_record.created_at.isoformat(),
            'priority': 'high'
        }
        
        logger.info(f"📞 Payload notifica: {json.dumps(notification_payload, indent=2)}")
        
        # Invia al server di notifiche SecureVOX
        import requests
        response = requests.post(
            'http://localhost:8002/send',
            json=notification_payload,
            timeout=5
        )
        
        if response.status_code == 200:
            logger.info(f"✅ Notifica chiamata inviata con successo a {call_record.callee.username}")
        else:
            logger.error(f"❌ Errore invio notifica chiamata: {response.status_code} - {response.text}")
            
    except Exception as e:
        logger.error(f"❌ Errore generale invio notifica chiamata: {e}")
        # Non interrompere la creazione della chiamata per problemi di notifica


def _send_call_ended_notification(call_record, ended_by_user, target_user):
    """
    Invia notifica di chiamata terminata all'altro partecipante
    
    Args:
        call_record: Record della chiamata dal database
        ended_by_user: Utente che ha terminato la chiamata
        target_user: Utente che deve ricevere la notifica
    """
    try:
        logger.info(f"📞 Invio notifica termine chiamata a {target_user.username}")
        
        # Payload notifica termine chiamata
        notification_payload = {
            'recipient_id': str(target_user.id),
            'sender_id': str(ended_by_user.id),
            'notification_type': 'system',
            'title': 'Chiamata terminata',
            'body': f'{ended_by_user.first_name or ended_by_user.username} ha terminato la chiamata',
            'data': {
                'session_id': call_record.session_id,
                'ended_by_id': str(ended_by_user.id),
                'ended_by_name': f"{ended_by_user.first_name} {ended_by_user.last_name}".strip() or ended_by_user.username,
                'call_type': call_record.call_type,
                'action': 'call_ended',
                'duration': str(call_record.ended_at - call_record.created_at) if call_record.ended_at else '0:00'
            },
            'timestamp': timezone.now().isoformat(),
            'priority': 'normal'
        }
        
        logger.info(f"📞 Payload notifica termine: {json.dumps(notification_payload, indent=2)}")
        
        # Invia al server di notifiche SecureVOX
        import requests
        response = requests.post(
            'http://localhost:8002/send',
            json=notification_payload,
            timeout=5
        )
        
        if response.status_code == 200:
            logger.info(f"✅ Notifica termine chiamata inviata a {target_user.username}")
        else:
            logger.error(f"❌ Errore invio notifica termine: {response.status_code} - {response.text}")
            
    except Exception as e:
        logger.error(f"❌ Errore generale invio notifica termine: {e}")


@api_view(['GET'])
@permission_classes([AllowAny])
def health(request):
    """Health check endpoint"""
    return Response({"ok": True, "service": "SecureVOX API"})


@api_view(['GET'])
@permission_classes([AllowAny])
def version(request):
    """Version endpoint"""
    return Response({
        "name": "SecureVOX API",
        "version": "1.0.0",
        "build": "stable"
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_users(request):
    """Ottiene tutti gli utenti attivi ESCLUDENDO l'utente corrente - REQUIRES AUTHENTICATION"""
    # SECURITY FIX: Added authentication requirement
    try:
        from admin_panel.models import UserProfile
        
        # Filtra gli utenti attivi ESCLUDENDO l'utente corrente
        users = User.objects.filter(is_active=True).exclude(id=request.user.id).select_related('profile')
        
        # Converti in formato compatibile con UserModel
        users_list = []
        for user in users:
            full_name = f"{user.first_name} {user.last_name}".strip()
            if not full_name:
                full_name = user.username
            
            # Ottieni l'avatar_url dal profilo se esiste
            avatar_url = ''
            try:
                if hasattr(user, 'profile') and user.profile.avatar_url:
                    avatar_url = user.profile.avatar_url
            except:
                pass
            
            users_list.append({
                'id': str(user.id),
                'name': full_name,
                'email': user.email,
                # 'password' field removed for security - CRITICAL FIX
                'createdAt': user.date_joined.isoformat(),
                'updatedAt': user.date_joined.isoformat(),
                'isActive': True,
                'profileImage': avatar_url,  # Usa l'avatar reale o stringa vuota
            })
        
        return Response(users_list)
    except Exception as e:
        logger.error(f"Errore nel recupero utenti: {e}")
        return Response({"error": "Errore interno del server"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([AllowAny])
def register_device(request):
    """Registra un nuovo dispositivo"""
    try:
        # Verifica autenticazione
        if not request.user.is_authenticated:
            return Response(
                {"error": "Authentication required"}, 
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        data = request.data
        device_name = data.get('device_name')
        device_type = data.get('device_type')
        device_fingerprint = data.get('device_fingerprint')
        fcm_token = data.get('fcm_token')
        apns_token = data.get('apns_token')
        
        if not all([device_name, device_type, device_fingerprint]):
            return Response(
                {"error": "Missing required fields"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Usa l'utente autenticato
        user = request.user
        
        # Crea il dispositivo
        device, device_created = Device.objects.get_or_create(
            device_fingerprint=device_fingerprint,
            defaults={
                'user': user,
                'device_name': device_name,
                'device_type': device_type,
                'fcm_token': fcm_token,
                'apns_token': apns_token,
            }
        )
        
        if not device_created:
            # Aggiorna token se dispositivo esiste
            device.fcm_token = fcm_token
            device.apns_token = apns_token
            device.is_active = True
            device.save()
        
        # Log dell'azione
        DeviceAuditLog.objects.create(
            device=device,
            action='register' if device_created else 'activate',
            ip_address=request.META.get('REMOTE_ADDR'),
            user_agent=request.META.get('HTTP_USER_AGENT')
        )
        
        return Response({
            "device_id": str(device.id),
            "status": "registered" if device_created else "updated"
        })
        
    except Exception as e:
        logger.error(f"Device registration failed: {e}")
        return Response(
            {"error": "Registration failed"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def upload_keybundle(request):
    """Carica il bundle di chiavi per un dispositivo (X3DH)"""
    try:
        device = request.user.device
        data = request.data
        
        identity_key_data = data.get('identity_key')
        signed_prekey_data = data.get('signed_prekey')
        one_time_prekeys = data.get('one_time_prekeys', [])
        
        # Salva identity key
        if identity_key_data:
            identity_key, created = IdentityKey.objects.get_or_create(
                device=device,
                defaults={
                    'public_key': base64.b64decode(identity_key_data['public_key']),
                    'private_key_encrypted': base64.b64decode(identity_key_data['private_key_encrypted'])
                }
            )
        
        # Salva signed prekey
        if signed_prekey_data:
            SignedPreKey.objects.create(
                device=device,
                key_id=signed_prekey_data['key_id'],
                public_key=base64.b64decode(signed_prekey_data['public_key']),
                signature=base64.b64decode(signed_prekey_data['signature']),
                expires_at=signed_prekey_data['expires_at']
            )
        
        # Salva one-time prekeys
        for prekey_data in one_time_prekeys:
            OneTimePreKey.objects.create(
                device=device,
                key_id=prekey_data['key_id'],
                public_key=base64.b64decode(prekey_data['public_key'])
            )
        
        return Response({"status": "keys_uploaded"})
        
    except Exception as e:
        logger.error(f"Key bundle upload failed: {e}")
        return Response(
            {"error": "Key upload failed"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
def get_keybundle(request, user_id):
    """Ottieni il bundle di chiavi per un utente (X3DH)"""
    try:
        target_user = User.objects.get(id=user_id)
        device = target_user.devices.filter(is_active=True).first()
        
        if not device:
            return Response(
                {"error": "No active device found"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Ottieni identity key
        identity_key = IdentityKey.objects.filter(device=device).first()
        identity_key_data = None
        if identity_key:
            identity_key_data = {
                'public_key': base64.b64encode(identity_key.public_key).decode()
            }
        
        # Ottieni signed prekey
        signed_prekey = SignedPreKey.objects.filter(device=device).first()
        signed_prekey_data = None
        if signed_prekey:
            signed_prekey_data = {
                'key_id': signed_prekey.key_id,
                'public_key': base64.b64encode(signed_prekey.public_key).decode(),
                'signature': base64.b64encode(signed_prekey.signature).decode()
            }
        
        # Ottieni one-time prekeys (non usati)
        one_time_prekeys = OneTimePreKey.objects.filter(
            device=device, 
            used_at__isnull=True
        )[:5]  # Limita a 5 chiavi
        
        one_time_prekeys_data = []
        for prekey in one_time_prekeys:
            one_time_prekeys_data.append({
                'key_id': prekey.key_id,
                'public_key': base64.b64encode(prekey.public_key).decode()
            })
        
        return Response({
            'identity_key': identity_key_data,
            'signed_prekey': signed_prekey_data,
            'one_time_prekeys': one_time_prekeys_data
        })
        
    except User.DoesNotExist:
        return Response(
            {"error": "User not found"}, 
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Key bundle retrieval failed: {e}")
        return Response(
            {"error": "Key retrieval failed"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_message(request):
    """Invia un messaggio cifrato (solo metadati)"""
    try:
        data = request.data
        recipient_id = data.get('recipient_id')
        message_type = data.get('message_type', 'text')
        encrypted_content_hash = data.get('encrypted_content_hash')
        
        if not all([recipient_id, encrypted_content_hash]):
            return Response(
                {"error": "Missing required fields"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        sender_device = request.user.device
        recipient_device = Device.objects.get(id=recipient_id)
        
        # Crea il messaggio (solo metadati)
        from crypto.models import Message
        message = Message.objects.create(
            sender=sender_device,
            recipient=recipient_device,
            message_type=message_type,
            encrypted_content_hash=encrypted_content_hash
        )
        
        # Crea notifica push cifrata
        NotificationQueue.objects.create(
            device=recipient_device,
            notification_type='message',
            encrypted_payload=data.get('encrypted_payload', b''),
            priority='normal'
        )
        
        return Response({
            "message_id": str(message.id),
            "status": "sent"
        })
        
    except Device.DoesNotExist:
        return Response(
            {"error": "Recipient device not found"}, 
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Message sending failed: {e}")
        return Response(
            {"error": "Message sending failed"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
def remote_wipe(request):
    """Invia comando di remote wipe a un dispositivo"""
    try:
        data = request.data
        device_id = data.get('device_id')
        reason = data.get('reason', 'Administrative action')
        
        if not device_id:
            return Response(
                {"error": "Device ID required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        target_device = Device.objects.get(id=device_id)
        
        # Crea comando di remote wipe
        wipe_command = RemoteWipeCommand.objects.create(
            device=target_device,
            initiated_by=request.user,
            reason=reason
        )
        
        # Crea notifica push per il wipe
        NotificationQueue.objects.create(
            device=target_device,
            notification_type='remote_wipe',
            encrypted_payload=data.get('encrypted_payload', b''),
            priority='urgent'
        )
        
        return Response({
            "wipe_command_id": str(wipe_command.id),
            "status": "dispatched"
        })
        
    except Device.DoesNotExist:
        return Response(
            {"error": "Device not found"}, 
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Remote wipe failed: {e}")
        return Response(
            {"error": "Remote wipe failed"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_ice_servers(request):
    """Ottieni server ICE per WebRTC"""
    try:
        # Prendi il primo dispositivo dell'utente o usa un ID generico
        from crypto.models import Device
        device = Device.objects.filter(user=request.user).first()
        
        if not device:
            # Se non ha dispositivi, crea uno temporaneo per i test
            device_id = f"temp_{request.user.id}"
        else:
            device_id = str(device.id)
        
        ice_servers = webrtc_service.get_ice_servers(
            user_id=request.user.id,
            device_id=device_id
        )
        
        return Response({
            "ice_servers": ice_servers
        })
        
    except Exception as e:
        logger.error(f"Failed to get ICE servers: {e}")
        return Response(
            {"error": "Failed to get ICE servers"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_call(request):
    """Crea una chiamata 1:1"""
    try:
        data = request.data
        callee_id = data.get('callee_id')
        call_type = data.get('call_type', 'video')
        
        if not callee_id:
            return Response(
                {"error": "Callee ID required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Trova l'utente destinatario
        from django.contrib.auth.models import User
        try:
            callee_user = User.objects.get(id=callee_id)
        except User.DoesNotExist:
            return Response(
                {"error": "Callee user not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Crea sessione di chiamata
        logger.info(f"🔍 Creando sessione chiamata: caller={request.user.id}, callee={callee_user.id}, type={call_type}")
        try:
            session = webrtc_service.create_call_session(
                caller_id=request.user.id,
                callee_id=callee_user.id,
                call_type=call_type
            )
            logger.info(f"✅ Sessione creata: {session}")
        except Exception as e:
            logger.error(f"❌ Errore creazione sessione: {e}")
            import traceback
            logger.error(f"❌ Traceback: {traceback.format_exc()}")
            return Response(
                {"error": f"Session creation failed: {str(e)}"}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        if session:
            # Salva la chiamata nel database per polling
            try:
                call_record = Call.objects.create(
                    session_id=session['session_id'],
                    caller=request.user,
                    callee=callee_user,
                    call_type=call_type,
                    status='ringing'
                )
                logger.info(f"✅ Call record creato: {call_record.id}")
                
                # IMPORTANTE: Invia notifica di chiamata in arrivo
                try:
                    _send_incoming_call_notification(call_record)
                except Exception as e:
                    logger.error(f"⚠️ Errore invio notifica chiamata: {e}")
                    
            except Exception as e:
                logger.error(f"⚠️ Errore creazione record chiamata: {e}")
                # Continuiamo comunque, il record non è critico
            
            return Response(session)
        else:
            logger.error("❌ create_call_session ha restituito None")
            return Response(
                {"error": "Failed to create call session"}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
    except Exception as e:
        logger.error(f"❌ Call creation failed: {e}")
        import traceback
        logger.error(f"❌ Traceback: {traceback.format_exc()}")
        return Response(
            {"error": "Failed to create call"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_pending_calls(request):
    """Ottieni chiamate in arrivo per l'utente"""
    try:
        # EMERGENZA: Controlla se il polling è bloccato
        from .emergency_views import check_polling_allowed
        if not check_polling_allowed(request):
            return Response({
                'error': 'POLLING_BLOCKED',
                'message': 'Polling temporaneamente bloccato per emergenza',
                'pending_calls': [],
                'count': 0
            }, status=429)  # Too Many Requests
        
        # Cerca chiamate in arrivo per l'utente corrente
        # CORREZIONE: Aumentato il timeout a 30 minuti per permettere chiamate più lunghe
        pending_calls = Call.objects.filter(
            callee=request.user,
            status='ringing',
            created_at__gte=timezone.now() - timedelta(minutes=30)  # Ultime 30 minuti
        ).order_by('-created_at')
        
        calls_data = []
        for call in pending_calls:
            calls_data.append({
                'session_id': call.session_id,
                'caller_id': str(call.caller.id),
                'caller_name': f"{call.caller.first_name} {call.caller.last_name}".strip() or call.caller.username,
                'caller_email': call.caller.email,
                'call_type': call.call_type,
                'created_at': call.created_at.isoformat(),
                'status': call.status
            })
        
        return Response({
            'pending_calls': calls_data,
            'count': len(calls_data)
        })
        
    except Exception as e:
        logger.error(f"Failed to get pending calls: {e}")
        return Response(
            {"error": "Failed to get pending calls"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_call_seen(request):
    """Marca una chiamata come vista"""
    try:
        session_id = request.data.get('session_id')
        if not session_id:
            return Response(
                {"error": "session_id required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Trova e aggiorna la chiamata
        call = Call.objects.filter(
            session_id=session_id,
            callee=request.user
        ).first()
        
        if call:
            call.status = 'seen'
            call.save()
            
            return Response({"status": "marked_as_seen"})
        else:
            return Response(
                {"error": "Call not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
    except Exception as e:
        logger.error(f"Failed to mark call as seen: {e}")
        return Response(
            {"error": "Failed to mark call as seen"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_group_call(request):
    """Crea una chiamata di gruppo"""
    try:
        data = request.data
        room_name = data.get('room_name', 'Group Call')
        max_participants = data.get('max_participants', 10)
        
        caller_device = request.user.device
        
        # Crea stanza di gruppo
        room = webrtc_service.create_group_call(
            creator_id=caller_device.user.id,
            room_name=room_name,
            max_participants=max_participants
        )
        
        if room:
            return Response(room)
        else:
            return Response(
                {"error": "Failed to create group call"}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
    except Exception as e:
        logger.error(f"Failed to create group call: {e}")
        return Response(
            {"error": "Failed to create group call"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def end_call(request):
    """Termina una chiamata e notifica l'altro partecipante"""
    try:
        data = request.data
        session_id = data.get('session_id')
        
        if not session_id:
            return Response(
                {"error": "Session ID required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        # Trova la chiamata nel database
        try:
            call_record = Call.objects.get(session_id=session_id)
            
            # Verifica che l'utente sia partecipante
            if call_record.caller.id != request.user.id and call_record.callee.id != request.user.id:
                return Response({
                    'error': 'UNAUTHORIZED',
                    'message': 'Non autorizzato per questa chiamata'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Aggiorna stato chiamata con logica intelligente
            old_status = call_record.status
            
            # Se era ancora "ringing", significa che è stata rifiutata o persa
            if old_status == 'ringing':
                call_record.status = 'missed'  # Chiamata persa/rifiutata
            else:
                call_record.status = 'ended'   # Chiamata normale terminata
                
            call_record.ended_at = timezone.now()
            
            # Calcola durata se la chiamata era stata accettata
            if hasattr(call_record, 'answered_at') and call_record.answered_at:
                call_record.duration = call_record.ended_at - call_record.answered_at
            else:
                call_record.duration = timezone.timedelta(seconds=0)  # Chiamata non accettata
                
            call_record.save()
            
            # Determina l'altro partecipante
            other_user = call_record.callee if call_record.caller.id == request.user.id else call_record.caller
            
            # Invia notifica di chiamata terminata all'altro partecipante
            try:
                _send_call_ended_notification(call_record, request.user, other_user)
            except Exception as e:
                logger.error(f"⚠️ Errore invio notifica termine chiamata: {e}")
            
            logger.info(f"✅ Chiamata terminata da user {request.user.id}: {session_id}")
            
        except Call.DoesNotExist:
            logger.warning(f"⚠️ Chiamata non trovata nel database: {session_id}")
        
        # Termina sessione nel servizio WebRTC
        success = webrtc_service.end_call_session(session_id)
        
        return Response({
            'message': 'Chiamata terminata con successo',
            'session_id': session_id,
            'ended_by': request.user.id,
            'ended_at': timezone.now().isoformat(),
            'status': 'call_ended'
        })
        
    except Exception as e:
        logger.error(f"❌ Failed to end call: {e}")
        return Response(
            {"error": "Failed to end call"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def update_call_status(request):
    """Aggiorna lo status di una chiamata (answered, rejected, etc.)"""
    try:
        data = request.data
        session_id = data.get('session_id')
        new_status = data.get('status')
        
        if not session_id or not new_status:
            return Response(
                {"error": "Session ID and status required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        # Trova la chiamata nel database
        try:
            call_record = Call.objects.get(session_id=session_id)
            
            # Verifica che l'utente sia partecipante
            if call_record.caller.id != request.user.id and call_record.callee.id != request.user.id:
                return Response({
                    'error': 'UNAUTHORIZED',
                    'message': 'Non autorizzato per questa chiamata'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Aggiorna status chiamata
            old_status = call_record.status
            call_record.status = new_status
            
            # Se la chiamata viene accettata, segna il timestamp
            if new_status == 'answered' and old_status == 'ringing':
                call_record.answered_at = timezone.now()
            
            call_record.save()
            
            logger.info(f"✅ Status chiamata aggiornato da user {request.user.id}: {session_id} ({old_status} → {new_status})")
            
            return Response({
                'message': 'Status chiamata aggiornato con successo',
                'session_id': session_id,
                'old_status': old_status,
                'new_status': new_status,
                'updated_by': request.user.id,
                'updated_at': timezone.now().isoformat(),
            })
            
        except Call.DoesNotExist:
            return Response(
                {"error": "Call not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
    except Exception as e:
        logger.error(f"❌ Errore aggiornamento status chiamata: {e}")
        return Response(
            {"error": "Status update failed"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_users_status(request):
    """Ottiene lo stato di tutti gli utenti"""
    try:
        from .status_manager import UserStatusManager
        
        status_data = UserStatusManager.get_all_users_status()
        
        return Response(status_data)
        
    except Exception as e:
        logger.error(f"❌ Errore recupero stati utenti: {e}")
        return Response(
            {"error": "Failed to get user statuses"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_my_status(request):
    """Aggiorna lo stato dell'utente corrente (heartbeat)"""
    try:
        from .status_manager import UserStatusManager
        
        data = request.data
        has_connection = data.get('has_connection', True)
        
        # Aggiorna attività utente
        status = UserStatusManager.update_user_activity(request.user, has_connection)
        
        return Response({
            'user_id': request.user.id,
            'status': status,
            'has_connection': has_connection,
            'updated_at': timezone.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"❌ Errore aggiornamento stato utente: {e}")
        return Response(
            {"error": "Failed to update status"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_calls(request):
    """Recupera la cronologia delle chiamate per l'utente corrente"""
    try:
        # Rate limiting: max 1 richiesta ogni 5 secondi per utente
        from django.core.cache import cache
        cache_key = f"get_calls_rate_limit_{request.user.id}"
        if cache.get(cache_key):
            return Response(
                {"error": "Too many requests. Please wait before making another call."},
                status=status.HTTP_429_TOO_MANY_REQUESTS
            )
        cache.set(cache_key, True, 5)  # 5 secondi di rate limiting
        
        user = request.user
        
        # Recupera tutte le chiamate dove l'utente è caller o callee
        calls = Call.objects.filter(
            models.Q(caller=user) | models.Q(callee=user)
        ).order_by('-timestamp')
        
        # Converte le chiamate in dizionari
        calls_data = []
        for call in calls:
            call_dict = call.to_dict()
            # Determina la direzione e il nome del contatto dal punto di vista dell'utente corrente
            if call.caller == user:
                # L'utente corrente è il chiamante
                call_dict['direction'] = 'outgoing'
                call_dict['contactName'] = call.callee.get_full_name() or call.callee.username
                call_dict['contactId'] = str(call.callee.id)
            else:
                # L'utente corrente è il ricevente
                call_dict['direction'] = 'incoming' if call.status != 'missed' else 'missed'
                call_dict['contactName'] = call.caller.get_full_name() or call.caller.username
                call_dict['contactId'] = str(call.caller.id)
            
            calls_data.append(call_dict)
        
        return Response({
            "calls": calls_data,
            "count": len(calls_data)
        })
        
    except Exception as e:
        logger.error(f"Failed to get calls: {e}")
        return Response(
            {"error": "Failed to get calls"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_chats(request):
    """Ottieni tutte le chat dell'utente corrente"""
    try:
        user = request.user
        
        # LOGICA GESTAZIONE CORRETTA:
        # Le chat in gestazione sono visibili SOLO all'utente che NON ha richiesto l'eliminazione
        chats = Chat.objects.filter(
            participants=user,
            is_active=True
        )
        
        # Filtra in base al tipo di chat
        filtered_chats = []
        for chat in chats:
            if chat.is_in_gestation:
                # Chat in gestazione: visibile solo a chi NON l'ha eliminata
                if chat.deletion_requested_by != user:
                    filtered_chats.append(chat)
            else:
                # Chat normale: visibile se l'utente non l'ha eliminata
                if not chat.deleted_by_users.filter(id=user.id).exists():
                    filtered_chats.append(chat)
        
        chats = filtered_chats
        
        chats_list = []
        for chat in chats:
            # Conta i messaggi non letti
            unread_count = ChatMessage.objects.filter(
                chat=chat,
                is_read=False
            ).exclude(sender=user).count()
            
            # Ottieni l'ultimo messaggio
            last_message_obj = ChatMessage.objects.filter(chat=chat).order_by('-created_at').first()
            last_message = last_message_obj.content if last_message_obj else ''
            last_message_at = last_message_obj.created_at if last_message_obj else chat.created_at
            last_message_sender_id = last_message_obj.sender.id if last_message_obj else None
            last_message_metadata = last_message_obj.metadata if last_message_obj else None
            
            # Determina il nome della chat e l'altro partecipante
            other_participant = None
            if chat.is_group:
                chat_name = chat.name
            else:
                # Per chat private, usa il nome dell'altro partecipante
                other_participant = chat.participants.exclude(id=user.id).first()
                if other_participant:
                    chat_name = f"{other_participant.first_name} {other_participant.last_name}".strip()
                    if not chat_name:
                        chat_name = other_participant.username
                else:
                    chat_name = chat.name
            
            # CORREZIONE: Assicurati che userId sia sempre popolato per chat individuali
            user_id = None
            if not chat.is_group and other_participant:
                user_id = str(other_participant.id)
            
            # DEBUG: Log dei dati della chat
            participants_list = [str(p.id) for p in chat.participants.all()]
            logger.info(f"🔍 Chat {chat.id}: is_group={chat.is_group}, other_participant={other_participant}, user_id={user_id}, participants={participants_list}")
            
            # CORREZIONE: Ottieni avatarUrl dell'altro partecipante
            avatar_url = ''
            if not chat.is_group and other_participant:
                try:
                    from admin_panel.models import UserProfile
                    if hasattr(other_participant, 'profile') and other_participant.profile.avatar_url:
                        avatar_url = other_participant.profile.avatar_url
                except:
                    pass
            
            # NUOVO: Informazioni gestazione
            gestation_info = {}
            if chat.is_in_gestation:
                gestation_info = {
                    'is_in_gestation': True,
                    'deletion_requested_by': str(chat.deletion_requested_by.id) if chat.deletion_requested_by else None,
                    'deletion_requested_by_name': chat.deletion_requested_by.first_name or chat.deletion_requested_by.username if chat.deletion_requested_by else None,
                    'deletion_requested_at': chat.deletion_requested_at.isoformat() if chat.deletion_requested_at else None,
                    'gestation_expires_at': chat.gestation_expires_at.isoformat() if chat.gestation_expires_at else None,
                    'is_read_only': True,
                    'gestation_notification_shown': chat.gestation_notification_shown,
                }
            else:
                gestation_info = {
                    'is_in_gestation': False,
                    'is_read_only': False,
                    'gestation_notification_shown': False,
                }
            
            chats_list.append({
                'id': str(chat.id),
                'name': chat_name,
                'lastMessage': last_message,
                'last_message_sender_id': last_message_sender_id,  # 🔐 E2EE: ID mittente ultimo messaggio
                'last_message_metadata': last_message_metadata,  # 🔐 E2EE: Metadati cifratura
                'timestamp': last_message_at.isoformat(),
                'avatarUrl': avatar_url,  # CORREZIONE: Avatar dell'altro partecipante
                'isOnline': False,  # Per ora sempre offline, da implementare
                'unreadCount': unread_count,
                'isGroup': chat.is_group,
                'groupMembers': [p.username for p in chat.participants.all()] if chat.is_group else [],
                'participants': participants_list,  # Aggiungi i participants
                'userId': user_id,  # CORREZIONE: userId per chat individuali
                **gestation_info,  # Aggiungi informazioni gestazione
            })
        
        return Response(chats_list)
        
    except Exception as e:
        logger.error(f"Errore nel recupero chat: {e}")
        return Response(
            {"error": "Errore interno del server"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_chat(request):
    """Crea una nuova chat"""
    try:
        data = request.data
        user = request.user
        participant_id = data.get('participant_id')
        is_group = data.get('is_group', False)
        group_name = data.get('group_name', '')
        
        if not participant_id and not is_group:
            return Response(
                {"error": "participant_id required for private chat"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Verifica se esiste già una chat privata ATTIVA con questo utente
        if not is_group:
            existing_chat = Chat.objects.filter(
                participants=user,
                is_group=False,
                is_active=True
            ).filter(participants__id=participant_id).exclude(
                # CORREZIONE: Permetti nuove chat se quella esistente è in gestation
                # o se l'utente corrente l'ha eliminata
                models.Q(is_in_gestation=True) | models.Q(deleted_by_users=user)
            ).first()
            
            if existing_chat:
                return Response({
                    "message": "Chat already exists",
                    "chat_id": str(existing_chat.id)
                })
        
        # Crea la nuova chat
        chat = Chat.objects.create(
            name=group_name if is_group else '',
            is_group=is_group,
            created_by=user,
            last_message='Chat creata',
            last_message_at=timezone.now()
        )
        
        # Aggiungi i partecipanti
        chat.participants.add(user)
        if not is_group and participant_id:
            try:
                participant = User.objects.get(id=participant_id)
                chat.participants.add(participant)
                # Aggiorna il nome della chat con il nome del partecipante
                participant_name = f"{participant.first_name} {participant.last_name}".strip()
                if not participant_name:
                    participant_name = participant.username
                chat.name = participant_name
                chat.save()
            except User.DoesNotExist:
                return Response(
                    {"error": "Participant not found"}, 
                    status=status.HTTP_404_NOT_FOUND
                )
        
        return Response({
            "message": "Chat created successfully",
            "chat_id": str(chat.id),
            "name": chat.name
        })
        
    except Exception as e:
        logger.error(f"Errore nella creazione chat: {e}")
        return Response(
            {"error": "Errore interno del server"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_chat(request, chat_id):
    """Elimina una chat per tutti i partecipanti con sincronizzazione realtime"""
    try:
        user = request.user
        logger.info(f"🗑️ ELIMINAZIONE CHAT {chat_id} da parte di {user.username}")
        
        # NUOVA LOGICA SEMPLICE: Verifica chi può eliminare
        try:
            # Trova la chat base (deve esistere ed essere attiva)
            chat = Chat.objects.filter(
                id=chat_id,
                is_active=True
            ).first()
            
            if not chat:
                logger.warning(f"❌ Chat {chat_id} non esiste")
                return Response(
                    {"error": "Chat not found"}, 
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Verifica che l'utente sia un partecipante
            if user not in chat.participants.all():
                participants = list(chat.participants.values_list('id', 'username'))
                logger.warning(f"❌ Utente {user.username} (ID: {user.id}) non è partecipante della chat {chat_id}")
                logger.warning(f"   Partecipanti: {participants}")
                return Response(
                    {"error": "Access denied - not a participant"}, 
                    status=status.HTTP_403_FORBIDDEN
                )
            
            # Controllo permessi per chat in gestazione
            if chat.is_in_gestation and chat.deletion_requested_by == user:
                logger.warning(f"❌ {user.username} ha richiesto la gestazione, non può eliminare")
                return Response(
                    {"error": "You requested deletion - other participants must decide"}, 
                    status=status.HTTP_403_FORBIDDEN
                )
            
            logger.info(f"✅ Chat trovata: {chat.id}, partecipanti: {[p.username for p in chat.participants.all()]}")
            
        except Exception as e:
            logger.error(f"Errore nel recupero chat: {e}")
            return Response(
                {"error": "Chat not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Ottieni tutti i partecipanti tranne l'utente che elimina
        other_participants = chat.participants.exclude(id=user.id)
        chat_name = chat.name
        chat_id_str = str(chat.id)
        
        # 1. Invia notifica realtime a tutti gli altri partecipanti
        _notifyChatDeletionToParticipants(
            chat_id=chat_id_str,
            chat_name=chat_name,
            deleted_by=user,
            participants=other_participants
        )
        
        # 2. Elimina fisicamente la chat dal database
        chat.delete()
        
        logger.info(f"🗑️ CHAT ELIMINATA: {chat_id_str} ({chat_name}) - Notificati {other_participants.count()} partecipanti")
        
        return Response({
            "message": "Chat deleted successfully",
            "chat_id": chat_id_str,
            "chat_name": chat_name,
            "deleted_by": user.username,
            "participants_notified": other_participants.count(),
            "deletion_type": "SYNC_DELETE"
        })
        
    except Exception as e:
        logger.error(f"Errore nell'eliminazione chat: {e}")
        return Response(
            {"error": "Errore interno del server"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


def _notifyChatDeletionToParticipants(chat_id, chat_name, deleted_by, participants):
    """Notifica l'eliminazione della chat a tutti i partecipanti"""
    try:
        import requests
        
        # Prepara i dati della notifica
        deletion_data = {
            'type': 'chat_deleted',
            'chat_id': chat_id,
            'chat_name': chat_name,
            'deleted_by': deleted_by.username,
            'deleted_by_name': deleted_by.first_name or deleted_by.username,
            'timestamp': timezone.now().isoformat(),
        }
        
        # Notifica ogni partecipante
        for participant in participants:
            try:
                # 1. Salva nella coda notifiche Django
                from crypto.models import Device
                participant_devices = Device.objects.filter(
                    user=participant, 
                    is_active=True, 
                    fcm_token__isnull=False
                )
                
                for device in participant_devices:
                    NotificationQueue.objects.create(
                        device=device,
                        notification_type='chat_deleted',
                        encrypted_payload=json.dumps(deletion_data).encode(),
                        priority='high'
                    )
                
                # 2. Invia tramite SecureVOX Notify per consegna immediata
                try:
                    notify_response = requests.post(
                        'http://localhost:8002/send',
                        json={
                            'recipient_id': str(participant.id),
                            'type': 'chat_deleted',
                            'chat_id': chat_id,
                            'chat_name': chat_name,
                            'deleted_by': deleted_by.username,
                            'deleted_by_name': deleted_by.first_name or deleted_by.username,
                            'timestamp': timezone.now().isoformat(),
                        },
                        timeout=3
                    )
                    logger.info(f"Notifica eliminazione inviata a {participant.username}: {notify_response.status_code}")
                except Exception as notify_error:
                    logger.warning(f"SecureVOX Notify non disponibile per {participant.username}: {notify_error}")
                
                logger.info(f"✅ Notifica eliminazione chat inviata a {participant.username}")
                
            except Exception as participant_error:
                logger.error(f"Errore notifica eliminazione per {participant.username}: {participant_error}")
        
    except Exception as e:
        logger.error(f"Errore generale notifica eliminazione chat: {e}")


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_chat_messages(request, chat_id):
    """Ottieni i messaggi di una chat"""
    try:
        user = request.user
        chat = Chat.objects.filter(
            participants=user,
            id=chat_id,
            is_active=True
        ).first()
        
        if not chat:
            return Response(
                {"error": "Chat not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # CORREZIONE: Filtra i messaggi eliminati dall'utente corrente
        messages = ChatMessage.objects.filter(chat=chat).exclude(
            deleted_for_users=user
        ).order_by('created_at')
        
        messages_list = []
        for message in messages:
            message_data = {
                'id': str(message.id),
                'content': message.content,
                'sender_id': str(message.sender.id),
                'sender_name': f"{message.sender.first_name} {message.sender.last_name}".strip() or message.sender.username,
                'message_type': message.message_type,
                'is_read': message.is_read,
                'created_at': message.created_at.isoformat(),
                'metadata': message.metadata,  # Includi i metadati nel campo metadata
                'is_deleted_for_me': False,  # Sempre False perché sono già filtrati
            }
            
            messages_list.append(message_data)
        
        return Response(messages_list)
        
    except Exception as e:
        logger.error(f"Errore nel recupero messaggi: {e}")
        return Response(
            {"error": "Errore interno del server"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_chat_message(request, chat_id):
    """Invia un messaggio a una chat"""
    try:
        user = request.user
        data = request.data
        
        # Verifica che la chat esista e l'utente ne faccia parte
        chat = Chat.objects.filter(
            participants=user,
            id=chat_id,
            is_active=True
        ).first()
        
        if not chat:
            return Response(
                {"error": "Chat not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        content = data.get('content', '').strip()
        message_type = data.get('message_type', 'text')
        
        if not content:
            return Response(
                {"error": "Message content is required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # 🔐 Prepara i metadati (inclusi quelli E2EE per messaggi cifrati)
        metadata = data.get('metadata', None)
        
        # Se metadata è già fornito (es. E2EE), usalo direttamente
        if metadata:
            print(f'🔐 Backend - Metadata ricevuto: {metadata}')
        
        # Prepara metadati specifici per tipo messaggio (merge con metadata esistenti)
        if message_type == 'image':
            image_url = data.get('image_url', '')
            caption = data.get('caption', '')
            print(f'🖼️ Backend - Messaggio immagine ricevuto:')
            print(f'   image_url: {image_url}')
            print(f'   caption: {caption}')
            print(f'   data completa: {data}')
            
            # Merge con metadata esistenti (es. E2EE)
            image_metadata = {
                'imageUrl': image_url,
                'caption': caption if caption else None
            }
            metadata = {**(metadata or {}), **image_metadata}
            print(f'   metadata creato: {metadata}')
        elif message_type == 'video':
            video_url = data.get('video_url', '')
            thumbnail_url = data.get('thumbnail_url', '')
            caption = data.get('caption', '')
            print(f'🎥 Backend - Messaggio video ricevuto:')
            print(f'   video_url: {video_url}')
            print(f'   thumbnail_url: {thumbnail_url}')
            print(f'   caption: {caption}')
            print(f'   data completa: {data}')
            
            # Merge con metadata esistenti (es. E2EE)
            video_metadata = {
                'videoUrl': video_url,
                'thumbnailUrl': thumbnail_url,
                'caption': caption if caption else None
            }
            metadata = {**(metadata or {}), **video_metadata}
            print(f'   metadata video creato: {metadata}')
        elif message_type == 'file':
            # CORREZIONE: Gestione messaggi file
            file_url = data.get('file_url', '')
            file_name = data.get('file_name', '')
            file_type = data.get('file_type', '')
            file_size = data.get('file_size', 0)
            file_extension = data.get('file_extension', '')
            mime_type = data.get('mime_type', '')
            caption = data.get('caption', '')
            metadata_dict = data.get('metadata', {})
            
            print(f'📄 Backend - Messaggio file ricevuto:')
            print(f'   file_url: {file_url}')
            print(f'   file_name: {file_name}')
            print(f'   file_type: {file_type}')
            print(f'   file_size: {file_size}')
            print(f'   metadata: {metadata_dict}')
            print(f'   data completa: {data}')
            
            metadata = {
                'file_url': file_url,
                'file_name': file_name,
                'file_type': file_type,
                'file_size': file_size,
                'file_extension': file_extension,
                'mime_type': mime_type,
                'caption': caption if caption else None,
                **metadata_dict  # Includi tutti i metadati aggiuntivi
            }
            print(f'   metadata file creato: {metadata}')
        elif message_type == 'contact':
            # Gestione messaggi contatto
            contact_name = data.get('contact_name', '')
            contact_phone = data.get('contact_phone', '')
            contact_email = data.get('contact_email', '')
            
            print(f'👤 Backend - Messaggio contatto ricevuto:')
            print(f'   contact_name: {contact_name}')
            print(f'   contact_phone: {contact_phone}')
            print(f'   contact_email: {contact_email}')
            
            # Merge con metadata esistenti (es. E2EE)
            contact_metadata = {
                'name': contact_name,
                'phone': contact_phone,
                'email': contact_email
            }
            metadata = {**(metadata or {}), **contact_metadata}
            print(f'   metadata contatto creato: {metadata}')
        elif message_type == 'location':
            # Gestione messaggi posizione
            latitude = data.get('latitude', 0.0)
            longitude = data.get('longitude', 0.0)
            address = data.get('address', '')
            city = data.get('city', '')
            country = data.get('country', '')
            
            print(f'📍 Backend - Messaggio posizione ricevuto:')
            print(f'   latitude: {latitude}')
            print(f'   longitude: {longitude}')
            print(f'   address: {address}')
            
            # Merge con metadata esistenti (es. E2EE)
            location_metadata = {
                'latitude': latitude,
                'longitude': longitude,
                'address': address,
                'city': city,
                'country': country,
            }
            metadata = {**(metadata or {}), **location_metadata}
            print(f'   metadata posizione creato: {metadata}')
        
        # Crea il messaggio
        message = ChatMessage.objects.create(
            chat=chat,
            sender=user,
            content=content,
            message_type=message_type,
            metadata=metadata
        )
        
        # Aggiorna last_message_at della chat
        chat.last_message_at = timezone.now()
        chat.save()
        
        # CORREZIONE: Invia notifica push a tutti i partecipanti tranne il mittente
        try:
            for participant in chat.participants.exclude(id=user.id):
                print(f"🔔 INVIO NOTIFICA A PARTICIPANT: {participant.id} ({participant.first_name} {participant.last_name})")
                
                # CORREZIONE: Invia direttamente al server notify usando user_id
                try:
                    notification_payload = {
                        'recipient_id': str(participant.id),
                        'title': f'Nuovo messaggio da {user.first_name or user.username}',
                        'body': content,
                        'data': {
                            'chat_id': str(chat.id),
                            'message_id': str(message.id),
                            'content': content,
                            'message_type': message_type,
                            'sender_name': user.first_name or user.username,
                            'timestamp': message.created_at.isoformat(),
                            # CORREZIONE: Aggiungi metadati media direttamente
                            'image_url': data.get('image_url', '') if message_type == 'image' else '',
                            'imageUrl': data.get('image_url', '') if message_type == 'image' else '',  # Compatibilità
                            'caption': data.get('caption', '') if message_type == 'image' else '',
                            'video_url': data.get('video_url', '') if message_type == 'video' else '',
                            'videoUrl': data.get('video_url', '') if message_type == 'video' else '',
                            'thumbnail_url': data.get('thumbnail_url', '') if message_type == 'video' else '',
                            'thumbnailUrl': data.get('thumbnail_url', '') if message_type == 'video' else '',
                            'audio_url': data.get('audio_url', '') if message_type == 'voice' else '',
                            'duration': data.get('duration', 0) if message_type == 'voice' else 0,
                            # CORREZIONE: Gestisci sia 'file' che 'attachment'
                            'file_name': data.get('file_name', '') if message_type in ['file', 'attachment'] else '',
                            'file_type': data.get('file_type', '') if message_type in ['file', 'attachment'] else '',
                            'file_url': data.get('file_url', '') if message_type in ['file', 'attachment'] else '',
                            'file_size': data.get('file_size', 0) if message_type in ['file', 'attachment'] else 0,
                            'file_extension': data.get('file_extension', '') if message_type in ['file', 'attachment'] else '',
                            'mime_type': data.get('mime_type', '') if message_type in ['file', 'attachment'] else '',
                            # Contact
                            'contact_name': data.get('contact_name', '') if message_type == 'contact' else '',
                            'contact_phone': data.get('contact_phone', '') if message_type == 'contact' else '',
                            'contact_email': data.get('contact_email', '') if message_type == 'contact' else '',
                            # Location
                            'latitude': data.get('latitude', 0.0) if message_type == 'location' else 0.0,
                            'longitude': data.get('longitude', 0.0) if message_type == 'location' else 0.0,
                            'address': data.get('address', '') if message_type == 'location' else '',
                            'city': data.get('city', '') if message_type == 'location' else '',
                            'country': data.get('country', '') if message_type == 'location' else '',
                            # CORREZIONE: Includi anche i metadati completi
                            'metadata': metadata if metadata else {},
                        },
                        'sender_id': str(user.id),
                        'timestamp': message.created_at.isoformat(),
                        'notification_type': 'message'
                    }
                    
                    print(f"🔔 INVIO NOTIFICA DIRETTA - Participant: {participant.id}, Chat: {chat.id}, Message: {message.id}")
                    print(f"🔔 PAYLOAD NOTIFICA: {json.dumps(notification_payload, indent=2)}")
                    
                    # CORREZIONE: Invia al server notify
                    import requests
                    response = requests.post(
                        'http://localhost:8002/send',
                        json=notification_payload,
                        timeout=5
                    )
                    
                    print(f"🔔 NOTIFICA RISPOSTA - Participant: {participant.id}, Status: {response.status_code}, Body: {response.text}")
                    
                    if response.status_code == 200:
                        print(f"✅ Notifica inviata con successo a {participant.first_name} {participant.last_name}")
                    else:
                        print(f"❌ Errore invio notifica a {participant.first_name} {participant.last_name}: {response.status_code}")
                        
                except Exception as notify_error:
                    print(f"❌ ERRORE NOTIFICA per {participant.id}: {notify_error}")
                    logger.warning(f"SecureVOX Notify non disponibile per {participant.id}: {notify_error}")
        except Exception as e:
            logger.warning(f"Errore generale nell'invio notifiche: {e}")
        
        return Response({
            "message_id": str(message.id),
            "status": "sent",
            "created_at": message.created_at.isoformat()
        })
        
    except Exception as e:
        logger.error(f"Errore nell'invio messaggio: {e}")
        return Response(
            {"error": "Errore interno del server"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_push_notification(request):
    """Invia una notifica push per un nuovo messaggio"""
    try:
        user = request.user
        data = request.data
        
        chat_id = data.get('chat_id')
        recipient_id = data.get('recipient_id')
        message_id = data.get('message_id')
        content = data.get('content', '')
        message_type = data.get('message_type', 'text')
        timestamp = data.get('timestamp')
        
        if not all([chat_id, recipient_id, message_id]):
            return Response(
                {"error": "chat_id, recipient_id e message_id sono obbligatori"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Verifica che la chat esista e l'utente ne faccia parte
        chat = Chat.objects.filter(
            participants=user,
            id=chat_id,
            is_active=True
        ).first()
        
        if not chat:
            return Response(
                {"error": "Chat not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Ottieni il destinatario
        try:
            recipient = User.objects.get(id=recipient_id)
        except User.DoesNotExist:
            return Response(
                {"error": "Recipient not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Ottieni i dispositivi attivi del destinatario
        try:
            from crypto.models import Device
            active_devices = Device.objects.filter(
                user=recipient, 
                is_active=True, 
                fcm_token__isnull=False
            )
        except Exception as e:
            logger.error(f"Errore nel recupero dispositivi: {e}")
            active_devices = Device.objects.none()
        
        # Prepara i dati della notifica
        notification_data = {
            'chat_id': chat_id,
            'message_id': message_id,
            'sender_id': str(user.id),
            'content': content,
            'message_type': message_type,
            'timestamp': timestamp or timezone.now().isoformat(),
        }
        
        # Salva la notifica nella coda
        try:
            for device in active_devices:
                NotificationQueue.objects.create(
                    device=device,
                    notification_type='message',
                    encrypted_payload=json.dumps(notification_data).encode(),
                    priority='normal'
                )
        except Exception as e:
            logger.error(f"Errore nel salvataggio notifica: {e}")
        
        # Invia notifica tramite SecureVOX Notify se disponibile
        try:
            import requests
            notify_response = requests.post(
                'http://localhost:8002/send',
                json={
                    'recipient_id': recipient_id,
                    'chat_id': chat_id,
                    'message_id': message_id,
                    'content': content,
                    'message_type': message_type,
                    'sender_name': user.first_name or user.username,
                    'timestamp': timestamp or timezone.now().isoformat(),
                },
                timeout=5
            )
            logger.info(f"Notifica inviata via SecureVOX Notify: {notify_response.status_code}")
        except Exception as e:
            logger.warning(f"SecureVOX Notify non disponibile: {e}")
        
        return Response({
            "status": "notification_sent",
            "recipient_id": recipient_id,
            "devices_count": active_devices.count(),
            "notification_data": notification_data
        })
        
    except Exception as e:
        logger.error(f"Errore nell'invio notifica push: {e}")
        return Response(
            {"error": "Errore interno del server"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_messages_as_read(request, chat_id):
    """Marca tutti i messaggi di una chat come letti"""
    try:
        user = request.user
        
        # Verifica che l'utente sia partecipante della chat
        chat = Chat.objects.filter(
            participants=user,
            id=chat_id,
            is_active=True
        ).first()
        
        if not chat:
            return Response(
                {"error": "Chat not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Marca tutti i messaggi non letti come letti
        try:
            # Prova ad aggiornare anche read_at se il campo esiste
            updated_count = ChatMessage.objects.filter(
                chat=chat,
                is_read=False
            ).exclude(
                sender=user  # Escludi i messaggi inviati dall'utente stesso
            ).update(
                is_read=True,
                read_at=timezone.now()
            )
        except Exception as e:
            # Fallback: aggiorna solo is_read se read_at non esiste
            logger.warning(f"Campo read_at non disponibile, aggiorno solo is_read: {e}")
            updated_count = ChatMessage.objects.filter(
                chat=chat,
                is_read=False
            ).exclude(
                sender=user
            ).update(
                is_read=True
            )
        
        logger.info(f"✅ {updated_count} messaggi marcati come letti per chat {chat_id} da utente {user.id}")
        
        return Response({
            "success": True,
            "updated_count": updated_count,
            "message": f"{updated_count} messaggi marcati come letti"
        })
        
    except Exception as e:
        logger.error(f"Errore nel marcare messaggi come letti: {e}")
        return Response(
            {"error": "Errore interno del server"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def delete_message_for_user(request, chat_id, message_id):
    """Elimina un messaggio solo per l'utente corrente (eliminazione locale)"""
    try:
        user = request.user
        
        # Verifica che la chat esista e l'utente ne faccia parte
        chat = Chat.objects.filter(
            participants=user,
            id=chat_id,
            is_active=True
        ).first()
        
        if not chat:
            return Response(
                {"error": "Chat not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Verifica che il messaggio esista nella chat
        try:
            message = ChatMessage.objects.get(
                id=message_id,
                chat=chat
            )
        except ChatMessage.DoesNotExist:
            return Response(
                {"error": "Message not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Controlla se il messaggio è già eliminato per questo utente
        if message.deleted_for_users.filter(id=user.id).exists():
            return Response(
                {"error": "Message already deleted for this user"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Aggiungi l'utente alla lista di quelli che hanno eliminato il messaggio
        message.deleted_for_users.add(user)
        
        logger.info(f"Messaggio {message_id} eliminato per utente {user.username} nella chat {chat_id}")
        
        return Response({
            "success": True,
            "message": "Messaggio eliminato con successo",
            "message_id": str(message.id),
            "deleted_for_user": str(user.id)
        })
        
    except Exception as e:
        logger.error(f"Errore nell'eliminazione messaggio: {e}")
        return Response(
            {"error": "Errore interno del server"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def request_chat_deletion(request, chat_id):
    """Richiede l'eliminazione di una chat con notifica all'altro utente"""
    try:
        user = request.user
        
        # Verifica che la chat esista e l'utente ne faccia parte
        chat = Chat.objects.filter(
            participants=user,
            id=chat_id,
            is_active=True
        ).first()
        
        if not chat:
            return Response(
                {"error": "Chat not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Verifica che sia una chat privata (non gruppo)
        if chat.is_group:
            return Response(
                {"error": "Group chat deletion not supported with this method"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Verifica che la chat non sia già in gestazione
        if chat.is_in_gestation:
            return Response(
                {"error": "Chat is already in gestation period"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Ottieni l'altro partecipante
        other_participant = chat.get_other_participant(user)
        if not other_participant:
            return Response(
                {"error": "Other participant not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Avvia il periodo di gestazione
        chat.start_gestation_period(user)
        
        # CORREZIONE: Aggiungi l'utente richiedente alla lista di eliminazioni
        chat.deleted_by_users.add(user)
        
        # Invia notifica all'altro utente
        try:
            notification_payload = {
                'recipient_id': str(other_participant.id),
                'title': f'{user.first_name or user.username} ha eliminato la chat',
                'body': f'Vuoi eliminare definitivamente la chat o mantenerla per 7 giorni?',
                'data': {
                    'notification_type': 'chat_deletion_request',
                    'chat_id': str(chat.id),
                    'requesting_user_id': str(user.id),
                    'requesting_user_name': user.first_name or user.username,
                    'expires_at': chat.gestation_expires_at.isoformat(),
                },
                'notification_type': 'chat_deletion_request'
            }
            
            # Invia al server notify
            import requests
            response = requests.post(
                'http://localhost:8002/send',
                json=notification_payload,
                timeout=5
            )
            
            if response.status_code == 200:
                chat.pending_deletion_notification_sent = True
                chat.save()
                logger.info(f"Notifica eliminazione chat inviata a {other_participant.username}")
            else:
                logger.warning(f"Errore invio notifica eliminazione: {response.status_code}")
                
        except Exception as notify_error:
            logger.warning(f"Errore notifica eliminazione: {notify_error}")
        
        logger.info(f"Chat {chat_id} messa in gestazione da {user.username}")
        
        return Response({
            "success": True,
            "message": "Chat eliminata. L'altro utente è stato notificato.",
            "chat_id": str(chat.id),
            "gestation_expires_at": chat.gestation_expires_at.isoformat(),
            "other_participant": other_participant.first_name or other_participant.username
        })
        
    except Exception as e:
        logger.error(f"Errore richiesta eliminazione chat: {e}")
        return Response(
            {"error": "Errore interno del server"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def respond_to_chat_deletion(request, chat_id):
    """Risponde alla richiesta di eliminazione chat"""
    try:
        user = request.user
        action = request.data.get('action')  # 'accept' o 'keep'
        
        if action not in ['accept', 'keep']:
            return Response(
                {"error": "Action must be 'accept' or 'keep'"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Verifica che la chat esista e sia in gestazione
        chat = Chat.objects.filter(
            participants=user,
            id=chat_id,
            is_in_gestation=True
        ).first()
        
        if not chat:
            return Response(
                {"error": "Chat not found or not in gestation"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Verifica che l'utente non sia quello che ha richiesto l'eliminazione
        if chat.deletion_requested_by == user:
            return Response(
                {"error": "Cannot respond to your own deletion request"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if action == 'accept':
            # Scenario 1: Eliminazione definitiva immediata
            logger.info(f"Chat {chat_id} eliminata definitivamente - accettata da {user.username}")
            chat.complete_deletion()
            
            return Response({
                "success": True,
                "message": "Chat eliminata definitivamente",
                "action": "deleted_permanently"
            })
            
        else:  # action == 'keep'
            # Scenario 2: Mantieni per N giorni (personalizzabili)
            custom_days = request.data.get('days', 7)  # Default 7 giorni
            
            # Valida i giorni (1-7)
            if not isinstance(custom_days, int) or custom_days < 1 or custom_days > 7:
                return Response(
                    {"error": "Days must be an integer between 1 and 7"}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Aggiorna la data di scadenza con i giorni personalizzati
            from django.utils import timezone
            chat.gestation_expires_at = timezone.now() + timezone.timedelta(days=custom_days)
            chat.save()
            
            days_text = f"{custom_days} {'giorno' if custom_days == 1 else 'giorni'}"
            logger.info(f"Chat {chat_id} mantenuta in gestazione da {user.username} per {days_text}")
            
            return Response({
                "success": True,
                "message": f"Chat mantenuta in sola lettura per {days_text}",
                "action": "kept_in_gestation",
                "days": custom_days,
                "expires_at": chat.gestation_expires_at.isoformat()
            })
        
    except Exception as e:
        logger.error(f"Errore risposta eliminazione chat: {e}")
        return Response(
            {"error": "Errore interno del server"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_gestation_notification_seen(request, chat_id):
    """Marca la notifica di gestazione come vista"""
    try:
        user = request.user
        
        # Trova la chat
        chat = Chat.objects.filter(
            participants=user,
            id=chat_id,
            is_active=True,
            is_in_gestation=True
        ).first()
        
        if not chat:
            return Response(
                {"error": "Chat not found or not in gestation"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Marca la notifica come vista
        chat.gestation_notification_shown = True
        chat.save()
        
        logger.info(f"✅ Notifica gestazione marcata come vista per chat {chat_id} da {user.username}")
        
        return Response({
            "success": True,
            "message": "Notification marked as seen"
        })
        
    except Exception as e:
        logger.error(f"Errore nel marcare notifica come vista: {e}")
        return Response(
            {"error": "Errore interno del server"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )



@api_view(['GET'])
@permission_classes([AllowAny])
def get_users_status(request):
    """
    Endpoint per ottenere lo stato di tutti gli utenti
    Basato su sistema di tracciamento reale login/logout
    """
    try:
        from .status_manager import UserStatusManager
        
        # Pulisce sessioni scadute prima di restituire stati
        UserStatusManager.cleanup_expired_sessions()
        
        # Ottiene stati aggiornati
        status_data = UserStatusManager.get_all_users_status()
        
        logger.info(f"📡 Stati utenti richiesti: {len(status_data)} utenti")
        return Response(status_data)
        
    except Exception as e:
        logger.error(f"Errore nel recupero stati utenti: {e}")
        return Response(
            {"error": "Errore interno del server"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_my_status(request):
    """
    Endpoint per aggiornare il proprio stato (heartbeat)
    """
    try:
        from .status_manager import UserStatusManager
        
        data = json.loads(request.body)
        has_connection = data.get('has_connection', True)
        
        # Aggiorna attività utente
        new_status = UserStatusManager.update_user_activity(request.user, has_connection)
        
        logger.info(f"📡 Stato aggiornato per user {request.user.id}: {new_status}")
        
        return Response({
            "success": True,
            "status": new_status,
            "message": f"Stato aggiornato a {new_status}"
        })
        
    except Exception as e:
        logger.error(f"Errore aggiornamento stato per user {request.user.id}: {e}")
        return Response(
            {"error": "Errore interno del server"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_call_timer(request, session_id):
    """Ottiene il timer condiviso della chiamata"""
    try:
        call = Call.objects.get(session_id=session_id)
        
        # Calcola il tempo trascorso dall'inizio della chiamata
        start_time = call.created_at
        current_time = timezone.now()
        elapsed_seconds = int((current_time - start_time).total_seconds())
        
        return Response({
            'session_id': session_id,
            'start_time': start_time.isoformat(),
            'current_time': current_time.isoformat(),
            'elapsed_seconds': elapsed_seconds,
            'status': call.status,
        })
        
    except Call.DoesNotExist:
        return Response(
            {"error": "Call not found"}, 
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"❌ Errore recupero timer chiamata: {e}")
        return Response(
            {"error": "Failed to get call timer"}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

