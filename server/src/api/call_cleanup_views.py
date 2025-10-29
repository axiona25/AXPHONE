"""
Views per cleanup automatico delle chiamate
"""
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from .models import Call
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta
from django.db import models
import logging

logger = logging.getLogger('securevox')

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def cleanup_user_calls(request):
    """Cleanup tutte le chiamate di un utente specifico"""
    try:
        user = request.user
        reason = request.data.get('reason', 'manual_cleanup')
        cleanup_type = request.data.get('cleanup_type', 'user_calls')
        
        logger.info(f"🧹 Cleanup chiamate per user {user.username} - Motivo: {reason}")
        
        # Trova tutte le chiamate attive dell'utente (come caller o callee)
        active_calls = Call.objects.filter(
            status='ringing'
        ).filter(
            models.Q(caller=user) | models.Q(callee=user)
        )
        
        calls_count = active_calls.count()
        
        # Termina tutte le chiamate
        for call in active_calls:
            call.status = 'ended'
            call.ended_at = timezone.now()
            call.save()
            
            logger.info(f"📞 Chiamata terminata: {call.session_id} ({call.caller.username} → {call.callee.username})")
        
        return Response({
            'success': True,
            'calls_cleaned': calls_count,
            'reason': reason,
            'cleanup_type': cleanup_type
        })
        
    except Exception as e:
        logger.error(f"Errore cleanup chiamate utente: {e}")
        return Response({'error': str(e)}, status=500)

@api_view(['POST'])
@permission_classes([AllowAny])
def cleanup_all_calls(request):
    """Cleanup TUTTE le chiamate attive (per sviluppo)"""
    try:
        reason = request.data.get('reason', 'manual_cleanup')
        cleanup_type = request.data.get('cleanup_type', 'all_calls')
        
        logger.info(f"🧹 Cleanup TUTTE le chiamate - Motivo: {reason}")
        
        # Trova tutte le chiamate attive
        active_calls = Call.objects.filter(status='ringing')
        calls_count = active_calls.count()
        
        # Termina tutte le chiamate
        active_calls.update(
            status='ended',
            ended_at=timezone.now()
        )
        
        logger.info(f"📞 {calls_count} chiamate terminate automaticamente")
        
        return Response({
            'success': True,
            'calls_cleaned': calls_count,
            'reason': reason,
            'cleanup_type': cleanup_type
        })
        
    except Exception as e:
        logger.error(f"Errore cleanup tutte le chiamate: {e}")
        return Response({'error': str(e)}, status=500)

@api_view(['POST'])
@permission_classes([AllowAny])
def cleanup_expired_calls(request):
    """Cleanup chiamate scadute (più vecchie di X minuti)"""
    try:
        max_minutes = request.data.get('max_minutes', 10)  # Default: 10 minuti
        
        cutoff_time = timezone.now() - timedelta(minutes=max_minutes)
        
        # Trova chiamate vecchie
        expired_calls = Call.objects.filter(
            status='ringing',
            created_at__lt=cutoff_time
        )
        
        calls_count = expired_calls.count()
        
        # Termina chiamate scadute
        expired_calls.update(
            status='ended',
            ended_at=timezone.now()
        )
        
        logger.info(f"📞 {calls_count} chiamate scadute pulite (più vecchie di {max_minutes} minuti)")
        
        return Response({
            'success': True,
            'calls_cleaned': calls_count,
            'max_minutes': max_minutes
        })
        
    except Exception as e:
        logger.error(f"Errore cleanup chiamate scadute: {e}")
        return Response({'error': str(e)}, status=500)
