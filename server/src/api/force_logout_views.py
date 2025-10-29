"""
Views per forzare logout di tutti gli utenti durante sviluppo
"""
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from rest_framework.authtoken.models import Token
from django.contrib.sessions.models import Session
from .models import UserStatus, AuthToken
import logging

logger = logging.getLogger('securevox')

@csrf_exempt
@require_http_methods(["POST"])
def force_logout_all_users(request):
    """
    SVILUPPO: Forza logout di tutti gli utenti eliminando tutti i token
    """
    try:
        # Conta token prima della pulizia
        auth_tokens_count = Token.objects.count()
        custom_tokens_count = AuthToken.objects.filter(is_active=True).count()
        sessions_count = Session.objects.count()
        online_users_count = UserStatus.objects.filter(is_logged_in=True).count()
        
        # 1. Elimina tutti i token standard Django
        Token.objects.all().delete()
        
        # 2. Disattiva tutti i token personalizzati
        AuthToken.objects.filter(is_active=True).update(is_active=False)
        
        # 3. Elimina tutte le sessioni Django
        Session.objects.all().delete()
        
        # 4. Imposta tutti gli utenti offline
        UserStatus.objects.filter(is_logged_in=True).update(
            is_logged_in=False,
            status='offline',
            has_connection=False,
            session_token=None
        )
        
        logger.warning(f"🔄 FORCE LOGOUT ALL: {auth_tokens_count} token standard, {custom_tokens_count} token personalizzati, {sessions_count} sessioni, {online_users_count} utenti online → TUTTI DISCONNESSI")
        
        return JsonResponse({
            'success': True,
            'message': 'Tutti gli utenti sono stati disconnessi',
            'stats': {
                'auth_tokens_deleted': auth_tokens_count,
                'custom_tokens_deactivated': custom_tokens_count,
                'sessions_deleted': sessions_count,
                'users_logged_out': online_users_count
            }
        })
        
    except Exception as e:
        logger.error(f"❌ Errore force logout all: {e}")
        return JsonResponse({
            'success': False,
            'error': str(e)
        }, status=500)


@csrf_exempt
@require_http_methods(["GET"])
def check_active_sessions(request):
    """
    Controlla quante sessioni attive ci sono
    """
    try:
        stats = {
            'auth_tokens': Token.objects.count(),
            'custom_tokens': AuthToken.objects.filter(is_active=True).count(),
            'sessions': Session.objects.count(),
            'online_users': UserStatus.objects.filter(is_logged_in=True).count(),
            'total_users': UserStatus.objects.count()
        }
        
        return JsonResponse({
            'success': True,
            'stats': stats
        })
        
    except Exception as e:
        logger.error(f"❌ Errore check sessions: {e}")
        return JsonResponse({
            'success': False,
            'error': str(e)
        }, status=500)
