"""
Views di debug per identificare problemi
"""

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
import logging

logger = logging.getLogger('securevox')

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def debug_call_creation(request):
    """Debug endpoint per testare la creazione di chiamate"""
    try:
        data = request.data
        callee_id = data.get('callee_id')
        call_type = data.get('call_type', 'video')
        
        logger.info(f"🔍 DEBUG: Ricevuta richiesta chiamata")
        logger.info(f"🔍 DEBUG: User: {request.user.id} ({request.user.username})")
        logger.info(f"🔍 DEBUG: Callee ID: {callee_id}")
        logger.info(f"🔍 DEBUG: Call type: {call_type}")
        
        if not callee_id:
            logger.error("❌ DEBUG: Callee ID mancante")
            return Response(
                {"error": "Callee ID required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Trova l'utente destinatario
        from django.contrib.auth.models import User
        try:
            callee_user = User.objects.get(id=callee_id)
            logger.info(f"✅ DEBUG: Callee trovato: {callee_user.username}")
        except User.DoesNotExist:
            logger.error(f"❌ DEBUG: Callee {callee_id} non trovato")
            return Response(
                {"error": "Callee user not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Test import webrtc_service
        try:
            from .webrtc_service import webrtc_service
            logger.info("✅ DEBUG: webrtc_service importato correttamente")
        except Exception as e:
            logger.error(f"❌ DEBUG: Errore import webrtc_service: {e}")
            return Response(
                {"error": f"WebRTC service import failed: {str(e)}"}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        # Test creazione sessione
        try:
            logger.info("🔍 DEBUG: Chiamando create_call_session...")
            session = webrtc_service.create_call_session(
                caller_id=request.user.id,
                callee_id=callee_user.id,
                call_type=call_type
            )
            logger.info(f"✅ DEBUG: Sessione creata: {session}")
            
            if session:
                return Response({
                    "success": True,
                    "session": session,
                    "debug_info": {
                        "caller_id": request.user.id,
                        "caller_username": request.user.username,
                        "callee_id": callee_user.id,
                        "callee_username": callee_user.username,
                        "call_type": call_type
                    }
                })
            else:
                logger.error("❌ DEBUG: create_call_session ha restituito None")
                return Response(
                    {"error": "create_call_session returned None"}, 
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
                
        except Exception as e:
            logger.error(f"❌ DEBUG: Errore in create_call_session: {e}")
            import traceback
            logger.error(f"❌ DEBUG: Traceback: {traceback.format_exc()}")
            return Response(
                {"error": f"Session creation failed: {str(e)}", "traceback": traceback.format_exc()}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
    except Exception as e:
        logger.error(f"❌ DEBUG: Errore generale: {e}")
        import traceback
        logger.error(f"❌ DEBUG: Traceback generale: {traceback.format_exc()}")
        return Response(
            {"error": f"General error: {str(e)}", "traceback": traceback.format_exc()}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
