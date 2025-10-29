"""
SecureVOX Call Integration API
Endpoints per integrare SecureVOX Call Server con Django backend
"""

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.contrib.auth.decorators import login_required
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.conf import settings
import json
import jwt
import logging
from datetime import datetime, timedelta

from .models import WebRTCCall, CallParticipant

logger = logging.getLogger(__name__)
User = get_user_model()

# Configurazione SecureVOX Call
SECUREVOX_CALL_JWT_SECRET = getattr(settings, 'SECUREVOX_CALL_JWT_SECRET', 'securevox-call-secret-2024')
SECUREVOX_CALL_SERVER_URL = getattr(settings, 'SECUREVOX_CALL_SERVER_URL', 'http://localhost:8002')

@csrf_exempt
@require_http_methods(["POST"])
@login_required
def generate_call_token(request):
    """
    Genera token JWT per SecureVOX Call Server
    """
    try:
        data = json.loads(request.body)
        user_id = data.get('userId') or str(request.user.id)
        session_id = data.get('sessionId')
        role = data.get('role', 'participant')
        
        if not session_id:
            return JsonResponse({'error': 'sessionId required'}, status=400)
        
        # Genera token JWT
        payload = {
            'userId': user_id,
            'sessionId': session_id,
            'role': role,
            'iat': int(timezone.now().timestamp()),
            'exp': int((timezone.now() + timedelta(hours=1)).timestamp())
        }
        
        token = jwt.encode(payload, SECUREVOX_CALL_JWT_SECRET, algorithm='HS256')
        
        # ICE servers configuration
        ice_servers = [
            {'urls': 'stun:stun.l.google.com:19302'},
            {'urls': 'stun:stun1.l.google.com:19302'},
            # TODO: Aggiungere TURN server proprietario
        ]
        
        logger.info(f"Generated call token for user {user_id}, session {session_id}")
        
        return JsonResponse({
            'token': token,
            'expires_in': 3600,
            'ice_servers': ice_servers,
            'server_url': SECUREVOX_CALL_SERVER_URL
        })
        
    except Exception as e:
        logger.error(f"Error generating call token: {e}")
        return JsonResponse({'error': 'Token generation failed'}, status=500)

@csrf_exempt
@require_http_methods(["POST"])
def call_server_webhook(request):
    """
    Webhook per ricevere aggiornamenti da SecureVOX Call Server
    """
    try:
        # Verifica autenticazione server
        auth_header = request.headers.get('X-SecureVOX-Call-Secret')
        if auth_header != SECUREVOX_CALL_JWT_SECRET:
            return JsonResponse({'error': 'Unauthorized'}, status=401)
        
        data = json.loads(request.body)
        session_id = data.get('sessionId')
        event = data.get('event')
        event_data = data.get('data', {})
        timestamp_str = data.get('timestamp')
        
        logger.info(f"Call server webhook: {event} for session {session_id}")
        
        # Trova la chiamata nel database
        try:
            call = WebRTCCall.objects.get(session_id=session_id)
        except WebRTCCall.DoesNotExist:
            logger.warning(f"Call not found in database: {session_id}")
            return JsonResponse({'error': 'Call not found'}, status=404)
        
        # Gestisci eventi
        if event == 'participant_joined':
            user_id = event_data.get('userId')
            if user_id:
                try:
                    user = User.objects.get(id=user_id)
                    participant, created = CallParticipant.objects.get_or_create(
                        call=call,
                        user=user,
                        defaults={'joined_at': timezone.now()}
                    )
                    if created:
                        logger.info(f"Participant {user_id} joined call {session_id}")
                except User.DoesNotExist:
                    logger.warning(f"User not found: {user_id}")
        
        elif event == 'participant_left':
            user_id = event_data.get('userId')
            if user_id:
                try:
                    participant = CallParticipant.objects.get(
                        call=call,
                        user_id=user_id
                    )
                    participant.left_at = timezone.now()
                    participant.save()
                    logger.info(f"Participant {user_id} left call {session_id}")
                except CallParticipant.DoesNotExist:
                    logger.warning(f"Participant not found: {user_id}")
        
        elif event == 'call_ended':
            reason = event_data.get('reason', 'unknown')
            call.status = 'ended'
            call.ended_at = timezone.now()
            call.end_reason = reason
            call.save()
            
            # Aggiorna tutti i partecipanti attivi
            CallParticipant.objects.filter(
                call=call,
                left_at__isnull=True
            ).update(left_at=timezone.now())
            
            logger.info(f"Call {session_id} ended: {reason}")
        
        return JsonResponse({'status': 'success'})
        
    except Exception as e:
        logger.error(f"Error processing call server webhook: {e}")
        return JsonResponse({'error': 'Webhook processing failed'}, status=500)

@csrf_exempt
@require_http_methods(["GET"])
@login_required
def call_stats(request):
    """
    Statistiche chiamate per l'utente corrente
    """
    try:
        user = request.user
        
        # Statistiche chiamate
        total_calls = WebRTCCall.objects.filter(
            participants__user=user
        ).distinct().count()
        
        active_calls = WebRTCCall.objects.filter(
            participants__user=user,
            status__in=['ringing', 'answered', 'connected']
        ).distinct().count()
        
        recent_calls = WebRTCCall.objects.filter(
            participants__user=user,
            created_at__gte=timezone.now() - timedelta(days=7)
        ).distinct().count()
        
        return JsonResponse({
            'total_calls': total_calls,
            'active_calls': active_calls,
            'recent_calls': recent_calls,
            'user_id': str(user.id)
        })
        
    except Exception as e:
        logger.error(f"Error getting call stats: {e}")
        return JsonResponse({'error': 'Stats retrieval failed'}, status=500)

@csrf_exempt
@require_http_methods(["POST"])
@login_required
def create_webrtc_call(request):
    """
    Crea una nuova chiamata WebRTC
    """
    try:
        data = json.loads(request.body)
        callee_id = data.get('callee_id')
        call_type = data.get('call_type', 'audio')
        session_id = data.get('session_id')
        
        if not callee_id:
            return JsonResponse({'error': 'callee_id required'}, status=400)
        
        if not session_id:
            # Genera session_id se non fornito
            timestamp = int(timezone.now().timestamp())
            session_id = f"call_{request.user.id}_{callee_id}_{timestamp}"
        
        try:
            callee = User.objects.get(id=callee_id)
        except User.DoesNotExist:
            return JsonResponse({'error': 'Callee not found'}, status=404)
        
        # Crea chiamata
        call = WebRTCCall.objects.create(
            session_id=session_id,
            caller=request.user,
            callee=callee,
            call_type=call_type,
            status='ringing',
            created_at=timezone.now()
        )
        
        # Aggiungi caller come partecipante
        CallParticipant.objects.create(
            call=call,
            user=request.user,
            joined_at=timezone.now()
        )
        
        logger.info(f"Created WebRTC call {session_id}: {request.user.id} -> {callee_id}")
        
        return JsonResponse({
            'session_id': session_id,
            'call_id': call.id,
            'status': 'ringing',
            'created_at': call.created_at.isoformat(),
            'caller': {
                'id': str(request.user.id),
                'name': request.user.get_full_name() or request.user.username
            },
            'callee': {
                'id': str(callee.id),
                'name': callee.get_full_name() or callee.username
            }
        })
        
    except Exception as e:
        logger.error(f"Error creating WebRTC call: {e}")
        return JsonResponse({'error': 'Call creation failed'}, status=500)

@csrf_exempt
@require_http_methods(["POST"])
@login_required
def end_webrtc_call(request):
    """
    Termina una chiamata WebRTC
    """
    try:
        data = json.loads(request.body)
        session_id = data.get('session_id')
        
        if not session_id:
            return JsonResponse({'error': 'session_id required'}, status=400)
        
        try:
            call = WebRTCCall.objects.get(session_id=session_id)
        except WebRTCCall.DoesNotExist:
            return JsonResponse({'error': 'Call not found'}, status=404)
        
        # Verifica che l'utente sia partecipante
        if not CallParticipant.objects.filter(call=call, user=request.user).exists():
            return JsonResponse({'error': 'Not authorized'}, status=403)
        
        # Termina chiamata
        call.status = 'ended'
        call.ended_at = timezone.now()
        call.end_reason = 'user_ended'
        call.save()
        
        # Aggiorna partecipanti attivi
        CallParticipant.objects.filter(
            call=call,
            left_at__isnull=True
        ).update(left_at=timezone.now())
        
        logger.info(f"Ended WebRTC call {session_id} by user {request.user.id}")
        
        return JsonResponse({
            'status': 'success',
            'session_id': session_id,
            'ended_at': call.ended_at.isoformat()
        })
        
    except Exception as e:
        logger.error(f"Error ending WebRTC call: {e}")
        return JsonResponse({'error': 'Call termination failed'}, status=500)
