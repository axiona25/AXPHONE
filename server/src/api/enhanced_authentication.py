"""
Sistema di autenticazione migliorato per SecureVox
Integra gestione stati utente in tempo reale
"""
from django.http import JsonResponse
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.models import User
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.contrib.auth.hashers import make_password, check_password
from django.core.exceptions import ValidationError, PermissionDenied
from django.core.validators import validate_email
from django.utils import timezone
from datetime import timedelta
from .models import AuthToken, PasswordResetToken
from .password_protection import PasswordProtection, protect_password_modification
from .status_manager import UserStatusManager
import json
import logging
import secrets
import hashlib

logger = logging.getLogger('securevox')


@api_view(['POST'])
@permission_classes([AllowAny])
def enhanced_register_user(request):
    """Registra un nuovo utente con gestione stati"""
    try:
        data = request.data
        name = data.get('name', '').strip()
        email = data.get('email', '').strip().lower()
        password = data.get('password', '')
        
        # Validazione input
        if not all([name, email, password]):
            return Response(
                {"message": "Tutti i campi sono obbligatori"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if len(name) < 2:
            return Response(
                {"message": "Il nome deve essere di almeno 2 caratteri"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if len(password) < 6:
            return Response(
                {"message": "La password deve essere di almeno 6 caratteri"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Validazione email
        try:
            validate_email(email)
        except ValidationError:
            return Response(
                {"message": "Indirizzo email non valido"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Verifica se l'email è già registrata
        if User.objects.filter(email=email).exists():
            return Response(
                {"message": "Email già registrata"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Verifica se l'username è già preso
        username = email.split('@')[0]
        counter = 1
        original_username = username
        while User.objects.filter(username=username).exists():
            username = f"{original_username}{counter}"
            counter += 1
        
        # Crea l'utente
        user = User.objects.create_user(
            username=username,
            email=email,
            password=password,
            first_name=name.split()[0] if name.split() else name,
            last_name=' '.join(name.split()[1:]) if len(name.split()) > 1 else ''
        )
        
        # Crea sessione utente (gestisce token e stati)
        session_data = UserStatusManager.create_user_session(user)
        
        # Prepara i dati dell'utente per la risposta
        user_data = {
            'id': str(user.id),
            'name': f"{user.first_name} {user.last_name}".strip(),
            'email': user.email,
            'username': user.username,
            'profileImage': '',  # Avatar vuoto per nuovi utenti
            'created_at': user.date_joined.isoformat(),
            'updated_at': user.date_joined.isoformat(),
            'is_active': user.is_active,
        }
        
        return Response({
            "user": user_data,
            "token": session_data['auth_token'],
            "message": "Registrazione completata con successo"
        }, status=status.HTTP_201_CREATED)
        
    except Exception as e:
        logger.error(f"User registration failed: {e}")
        return Response(
            {"message": "Errore durante la registrazione"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([AllowAny])
def enhanced_login_user(request):
    """Login utente con gestione stati"""
    try:
        data = request.data
        email = data.get('email', '').strip().lower()
        password = data.get('password', '')
        
        # Validazione input
        if not all([email, password]):
            return Response(
                {"message": "Email e password sono obbligatori"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Cerca l'utente per email
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response(
                {"message": "Utente non trovato"},
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        # Verifica la password usando authenticate
        authenticated_user = authenticate(username=user.username, password=password)
        if not authenticated_user:
            return Response(
                {"message": "Credenziali non valide"},
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        # Verifica se l'utente è attivo
        if not user.is_active:
            return Response(
                {"message": "Account disabilitato"},
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        # Crea sessione utente (gestisce token e stati)
        session_data = UserStatusManager.create_user_session(user)
        
        # Ottieni l'avatar dal profilo se esiste
        avatar_url = ''
        try:
            from admin_panel.models import UserProfile
            profile = UserProfile.objects.get(user=user)
            avatar_url = profile.avatar_url or ''
        except:
            pass
        
        # Prepara i dati dell'utente per la risposta
        user_data = {
            'id': str(user.id),
            'name': f"{user.first_name} {user.last_name}".strip(),
            'email': user.email,
            'username': user.username,
            'profileImage': avatar_url,
            'created_at': user.date_joined.isoformat(),
            'updated_at': user.date_joined.isoformat(),
            'is_active': user.is_active,
        }
        
        # Usa standard_token come fallback se auth_token è None
        token_to_use = session_data.get('auth_token') or session_data.get('standard_token')
        
        return Response({
            "user": user_data,
            "token": token_to_use,
            "message": "Login effettuato con successo"
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"User login failed: {e}")
        return Response(
            {"message": f"Errore durante il login: {str(e)}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def enhanced_logout_user(request):
    """Logout utente con gestione stati"""
    try:
        # Distrugge sessione utente (gestisce token e stati)
        UserStatusManager.destroy_user_session(request.user)
        
        return Response({
            "message": "Logout effettuato con successo"
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"User logout failed: {e}")
        return Response(
            {"message": "Errore durante il logout"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def enhanced_verify_token(request):
    """Verifica la validità del token con aggiornamento attività"""
    try:
        # Aggiorna attività utente (heartbeat automatico)
        UserStatusManager.update_user_activity(request.user, True)
        
        # Ottieni l'avatar dal profilo se esiste
        avatar_url = ''
        try:
            from admin_panel.models import UserProfile
            profile = UserProfile.objects.get(user=request.user)
            avatar_url = profile.avatar_url or ''
        except:
            pass
        
        user_data = {
            'id': str(request.user.id),
            'name': f"{request.user.first_name} {request.user.last_name}".strip(),
            'email': request.user.email,
            'username': request.user.username,
            'profileImage': avatar_url,
            'created_at': request.user.date_joined.isoformat(),
            'updated_at': request.user.date_joined.isoformat(),
            'is_active': request.user.is_active,
        }
        
        return Response({
            "valid": True,
            "user": user_data
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Token verification failed: {e}")
        return Response(
            {"valid": False, "message": "Token non valido"},
            status=status.HTTP_401_UNAUTHORIZED
        )
