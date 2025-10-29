"""
Views per debug e controllo del polling chiamate
"""
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from .models import Call
from django.contrib.auth.models import User
import logging

logger = logging.getLogger('securevox')

@api_view(['GET'])
@permission_classes([AllowAny])
def debug_active_calls(request):
    """Debug: Mostra tutte le chiamate attive"""
    try:
        active_calls = Call.objects.filter(status='ringing').order_by('-created_at')
        
        calls_data = []
        for call in active_calls:
            calls_data.append({
                'session_id': call.session_id,
                'caller': call.caller.username,
                'callee': call.callee.username,
                'call_type': call.call_type,
                'created_at': call.created_at.isoformat(),
                'minutes_ago': (call.created_at - call.created_at).total_seconds() / 60
            })
        
        return Response({
            'active_calls_count': len(calls_data),
            'calls': calls_data
        })
        
    except Exception as e:
        logger.error(f"Errore debug active calls: {e}")
        return Response({'error': str(e)}, status=500)

@api_view(['POST'])
@permission_classes([AllowAny])
def force_app_polling_restart(request):
    """Debug: Forza restart polling su tutte le app connesse"""
    try:
        # Questo endpoint può essere chiamato dalle app per forzare restart
        user_id = request.data.get('user_id')
        
        if user_id:
            user = User.objects.get(id=user_id)
            logger.info(f"🔄 Force restart polling richiesto per user {user.username}")
        else:
            logger.info(f"🔄 Force restart polling richiesto (globale)")
        
        # Reset emergency stop
        try:
            import api.emergency_views as emergency_views
            emergency_views._polling_blocked_until = None
            logger.info("🔄 Emergency stop reset")
        except Exception as e:
            logger.warning(f"⚠️ Impossibile resettare emergency stop: {e}")
        
        return Response({
            'status': 'restart_requested',
            'message': 'Restart polling forzato',
            'user_id': user_id
        })
        
    except Exception as e:
        logger.error(f"Errore force restart polling: {e}")
        return Response({'error': str(e)}, status=500)
