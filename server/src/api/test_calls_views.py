"""
Endpoint di test per verificare le chiamate senza autenticazione
"""

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from django.contrib.auth.models import User
from .models import Call
import logging

logger = logging.getLogger('securevox')

@api_view(['GET'])
@permission_classes([AllowAny])
def test_pending_calls_for_user(request, user_id):
    """
    Test endpoint per vedere le chiamate in arrivo di un utente specifico
    NON USARE IN PRODUZIONE - Solo per debug
    """
    try:
        user = User.objects.get(id=user_id)
        
        # Cerca chiamate in arrivo per l'utente
        pending_calls = Call.objects.filter(
            callee=user,
            status='ringing'
        ).order_by('-created_at')
        
        calls_data = []
        for call in pending_calls:
            calls_data.append({
                'session_id': call.session_id,
                'caller_id': str(call.caller.id),
                'caller_name': f"{call.caller.first_name} {call.caller.last_name}".strip() or call.caller.username,
                'caller_email': call.caller.email,
                'call_type': call.call_type,
                'is_encrypted': call.is_encrypted,
                'created_at': call.created_at.isoformat(),
                'status': call.status
            })
        
        logger.info(f"📞 Test pending calls per user {user_id}: {len(calls_data)} chiamate")
        
        return Response({
            'user_id': user_id,
            'username': user.username,
            'pending_calls': calls_data,
            'count': len(calls_data),
            'test_mode': True
        })
        
    except User.DoesNotExist:
        return Response({
            'error': 'USER_NOT_FOUND',
            'message': f'Utente {user_id} non trovato'
        }, status=404)
    except Exception as e:
        logger.error(f"Test pending calls error: {e}")
        return Response({
            'error': 'TEST_ERROR',
            'message': str(e)
        }, status=500)


@api_view(['POST'])
@permission_classes([AllowAny])
def test_create_call_direct(request):
    """
    Test endpoint per creare una chiamata direttamente
    NON USARE IN PRODUZIONE - Solo per debug
    """
    try:
        caller_id = request.data.get('caller_id')
        callee_id = request.data.get('callee_id')
        call_type = request.data.get('call_type', 'audio')
        
        if not caller_id or not callee_id:
            return Response({
                'error': 'MISSING_IDS',
                'message': 'caller_id e callee_id richiesti'
            }, status=400)
        
        # Trova utenti
        caller = User.objects.get(id=caller_id)
        callee = User.objects.get(id=callee_id)
        
        # Crea session ID
        import time
        session_id = f"test_call_{caller_id}_{callee_id}_{int(time.time())}"
        
        # Crea record chiamata
        import uuid
        call_record = Call.objects.create(
            id=uuid.uuid4(),  # UUID corretto
            session_id=session_id,
            caller=caller,
            callee=callee,
            call_type=call_type,
            status='ringing',
            is_encrypted=True
        )
        
        # Invia notifica
        try:
            from .views import _send_incoming_call_notification
            _send_incoming_call_notification(call_record)
        except Exception as e:
            logger.error(f"Errore invio notifica: {e}")
        
        logger.info(f"📞 Test chiamata creata: {session_id}")
        
        return Response({
            'session_id': session_id,
            'caller': {
                'id': caller.id,
                'username': caller.username
            },
            'callee': {
                'id': callee.id,
                'username': callee.username
            },
            'call_type': call_type,
            'status': 'ringing',
            'is_encrypted': True,
            'notification_sent': True,
            'test_mode': True
        })
        
    except User.DoesNotExist:
        return Response({
            'error': 'USER_NOT_FOUND',
            'message': 'Uno degli utenti non trovato'
        }, status=404)
    except Exception as e:
        logger.error(f"Test create call error: {e}")
        return Response({
            'error': 'TEST_ERROR',
            'message': str(e)
        }, status=500)
