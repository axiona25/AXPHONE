"""
Endpoint di emergenza per gestire loop infiniti
"""

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
import logging

logger = logging.getLogger('securevox')

# Variabile globale per bloccare polling abusivo
POLLING_BLOCKED = False
BLOCKED_IPS = set()

@api_view(['POST'])
@permission_classes([AllowAny])
def emergency_stop_polling(request):
    """
    Endpoint di emergenza per fermare loop di polling infiniti
    """
    global POLLING_BLOCKED
    
    try:
        action = request.data.get('action', 'stop')
        
        if action == 'stop':
            POLLING_BLOCKED = True
            logger.warning("🚨 EMERGENZA: Polling bloccato globalmente")
            
            return Response({
                'status': 'polling_blocked',
                'message': 'Polling fermato per emergenza',
                'timestamp': '2025-09-20T14:46:30Z'
            })
            
        elif action == 'resume':
            POLLING_BLOCKED = False
            BLOCKED_IPS.clear()
            logger.info("✅ EMERGENZA: Polling riabilitato")
            
            return Response({
                'status': 'polling_resumed',
                'message': 'Polling riabilitato',
                'timestamp': '2025-09-20T14:46:30Z'
            })
            
        else:
            return Response({
                'error': 'INVALID_ACTION',
                'message': 'Azione deve essere "stop" o "resume"'
            }, status=400)
            
    except Exception as e:
        logger.error(f"Emergency endpoint error: {e}")
        return Response({
            'error': 'EMERGENCY_ERROR',
            'message': str(e)
        }, status=500)


@api_view(['GET'])
@permission_classes([AllowAny])
def emergency_status(request):
    """
    Verifica stato emergenza polling
    """
    return Response({
        'polling_blocked': POLLING_BLOCKED,
        'blocked_ips_count': len(BLOCKED_IPS),
        'timestamp': '2025-09-20T14:46:30Z'
    })


def check_polling_allowed(request):
    """
    Middleware function per controllare se il polling è permesso
    """
    global POLLING_BLOCKED, BLOCKED_IPS
    
    if POLLING_BLOCKED:
        client_ip = request.META.get('REMOTE_ADDR', 'unknown')
        BLOCKED_IPS.add(client_ip)
        
        logger.warning(f"🚨 Polling bloccato per IP: {client_ip}")
        return False
    
    return True
