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
from .models import AuthToken
from .password_protection import PasswordProtection, protect_password_modification
import json
import logging
import secrets
import hashlib

logger = logging.getLogger('securevox')


@api_view(['POST'])
@permission_classes([AllowAny])
def register_user(request):
    """Registra un nuovo utente"""
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
        
        # Usa il UserStatusManager per creare la sessione completa
        from .status_manager import UserStatusManager
        session_data = UserStatusManager.create_user_session(user)
        token_key = session_data['standard_token']
        
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
            "token": token_key,
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
def login_user(request):
    """Login utente"""
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
        
        # Usa il UserStatusManager per creare la sessione completa
        from .status_manager import UserStatusManager
        session_data = UserStatusManager.create_user_session(user)
        token_key = session_data['standard_token']
        
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
            "token": token_key,
            "message": "Login effettuato con successo"
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"User login failed: {e}")
        print(f"Login error: {e}")
        return Response(
            {"message": f"Errore durante il login: {str(e)}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def logout_user(request):
    """Logout utente"""
    try:
        # Usa il manager per gestire il logout completo
        from .status_manager import UserStatusManager
        UserStatusManager.destroy_user_session(request.user)
        
        logger.info(f"🔐 Logout completato per user {request.user.id}")
        return Response({
            "message": "Logout effettuato con successo"
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"User logout failed: {e}")
        return Response(
            {"message": "Errore durante il logout"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])  # Usa autenticazione normale
def auto_logout(request):
    """Logout automatico per hot reload/ricompilazione app"""
    try:
        # Se arriviamo qui, l'utente è già autenticato dal middleware
        user = request.user
        
        # Usa il manager per gestire il logout completo
        from .status_manager import UserStatusManager
        UserStatusManager.destroy_user_session(user)
        
        logger.info(f"🔐 Auto-logout completato per user {user.id} (hot reload)")
        return Response({
            "message": "Auto-logout effettuato con successo"
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Auto-logout failed: {e}")
        return Response({
            "message": "Errore durante auto-logout"
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def verify_token(request):
    """Verifica la validità del token"""
    try:
        # Se arriviamo qui, il token è valido
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


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def update_profile(request):
    """Aggiorna il profilo utente"""
    try:
        data = request.data
        user = request.user
        
        # Aggiorna i campi se forniti
        if 'name' in data:
            name = data['name'].strip()
            if name:
                name_parts = name.split()
                user.first_name = name_parts[0] if name_parts else name
                user.last_name = ' '.join(name_parts[1:]) if len(name_parts) > 1 else ''
        
        if 'bio' in data:
            # Aggiungi campo bio se non esiste nel modello User
            # Per ora lo ignoriamo o lo salviamo in un campo personalizzato
            pass
        
        if 'phone' in data:
            # Aggiungi campo phone se non esiste nel modello User
            # Per ora lo ignoriamo o lo salviamo in un campo personalizzato
            pass
        
        if 'location' in data:
            # Aggiungi campo location se non esiste nel modello User
            # Per ora lo ignoriamo o lo salviamo in un campo personalizzato
            pass
        
        if 'date_of_birth' in data:
            # Aggiungi campo date_of_birth se non esiste nel modello User
            # Per ora lo ignoriamo o lo salviamo in un campo personalizzato
            pass
        
        user.save()
        
        # Prepara i dati dell'utente aggiornato
        user_data = {
            'id': str(user.id),
            'name': f"{user.first_name} {user.last_name}".strip(),
            'email': user.email,
            'username': user.username,
            'created_at': user.date_joined.isoformat(),
            'updated_at': user.date_joined.isoformat(),
            'is_active': user.is_active,
        }
        
        return Response({
            "user": user_data,
            "message": "Profilo aggiornato con successo"
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Profile update failed: {e}")
        return Response(
            {"message": "Errore durante l'aggiornamento del profilo"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def upload_avatar(request):
    """Carica la foto di profilo dell'utente"""
    try:
        if 'avatar' not in request.FILES:
            return Response(
                {"message": "Nessuna foto fornita"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        avatar_file = request.FILES['avatar']
        user = request.user
        
        # Verifica tipo file (solo immagini)
        if not avatar_file.content_type.startswith('image/'):
            return Response(
                {"message": "Il file deve essere un'immagine (JPEG, PNG)"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Verifica dimensioni (max 5MB)
        if avatar_file.size > 5 * 1024 * 1024:
            return Response(
                {"message": "L'immagine deve essere inferiore a 5MB"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Genera nome file univoco
        import uuid
        import os
        from django.core.files.storage import default_storage
        from django.core.files.base import ContentFile
        
        file_extension = os.path.splitext(avatar_file.name)[1]
        unique_filename = f"avatars/{user.id}_{uuid.uuid4()}{file_extension}"
        
        # Salva il file
        file_path = default_storage.save(unique_filename, ContentFile(avatar_file.read()))
        
        # Aggiorna il profilo utente con l'URL dell'avatar
        # Usa il modello UserProfile se esiste, altrimenti crea un record
        from admin_panel.models import UserProfile
        
        logger.info(f"Avatar upload - User ID: {user.id}, Username: {user.username}")
        
        try:
            # Prova prima a ottenere il profilo esistente
            profile = UserProfile.objects.get(user=user)
            logger.info(f"Avatar upload - Profile found for user {user.id}")
        except UserProfile.DoesNotExist:
            # Se non esiste, crealo
            profile = UserProfile.objects.create(
                user=user,
                tenant_id='00000000-0000-0000-0000-000000000001',
                phone_number='',
                bio='',
                location='',
                is_verified=False
            )
            logger.info(f"Avatar upload - Profile created for user {user.id}")
        except Exception as e:
            logger.error(f"Avatar upload - Error getting profile: {e}")
            raise
        
        # Aggiorna solo l'URL dell'avatar usando update invece di save
        try:
            UserProfile.objects.filter(user=user).update(
                avatar_url=f"/api/media/download/{file_path}"
            )
            # Ricarica il profilo per ottenere i dati aggiornati
            profile.refresh_from_db()
            logger.info(f"Avatar upload - Profile updated with avatar_url: {profile.avatar_url}")
        except Exception as e:
            logger.error(f"Avatar upload - Error updating profile: {e}")
            raise
        
        # Prepara i dati dell'utente aggiornato
        user_data = {
            'id': str(user.id),
            'name': f"{user.first_name} {user.last_name}".strip(),
            'email': user.email,
            'username': user.username,
            'profileImage': profile.avatar_url,  # Usa profileImage invece di avatar_url
            'created_at': user.date_joined.isoformat(),
            'updated_at': user.date_joined.isoformat(),
            'is_active': user.is_active,
        }
        
        return Response({
            "user": user_data,
            "message": "Foto di profilo aggiornata con successo"
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Avatar upload failed: {e}")
        return Response(
            {"message": "Errore durante il caricamento della foto"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([AllowAny])
def verify_email_exists(request):
    """Verifica se l'email esiste nel database degli utenti"""
    try:
        data = request.data
        email = data.get('email', '').strip().lower()
        
        if not email:
            return Response(
                {"message": "Email obbligatoria"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Verifica se l'email esiste nel database
        try:
            user = User.objects.get(email=email, is_active=True)
            logger.info(f"Email verification - User found: {user.id} ({email})")
            
            return Response({
                "exists": True,
                "user_id": str(user.id),
                "message": "Email trovata nel sistema"
            }, status=status.HTTP_200_OK)
            
        except User.DoesNotExist:
            logger.warning(f"Email verification - User not found: {email}")
            return Response({
                "exists": False,
                "message": "Email non trovata nel sistema"
            }, status=status.HTTP_404_NOT_FOUND)
        
    except Exception as e:
        logger.error(f"Email verification failed: {e}")
        return Response(
            {"message": "Errore durante la verifica email"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_avatar(request):
    """Elimina la foto di profilo dell'utente e torna alle iniziali"""
    try:
        user = request.user
        
        # Ottieni il profilo utente
        from admin_panel.models import UserProfile
        
        try:
            profile = UserProfile.objects.get(user=user)
            
            # Elimina l'URL dell'avatar (torna alle iniziali)
            UserProfile.objects.filter(user=user).update(avatar_url='')
            profile.refresh_from_db()
            
            logger.info(f"Avatar deleted for user {user.id}")
            
        except UserProfile.DoesNotExist:
            # Se il profilo non esiste, non c'è niente da eliminare
            logger.info(f"No profile found for user {user.id}, nothing to delete")
        
        # Prepara i dati dell'utente aggiornato
        user_data = {
            'id': str(user.id),
            'name': f"{user.first_name} {user.last_name}".strip(),
            'email': user.email,
            'username': user.username,
            'profileImage': '',  # Nessuna immagine, torna alle iniziali
            'created_at': user.date_joined.isoformat(),
            'updated_at': user.date_joined.isoformat(),
            'is_active': user.is_active,
        }
        
        return Response({
            "user": user_data,
            "message": "Foto di profilo eliminata con successo"
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Avatar deletion failed: {e}")
        return Response(
            {"message": "Errore durante l'eliminazione della foto"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def change_password(request):
    """Cambia la password dell'utente"""
    try:
        # Verifica se l'utente è protetto
        PasswordProtection.can_modify_password(request.user, "change")
        
        data = request.data
        current_password = data.get('current_password', '')
        new_password = data.get('new_password', '')
        
        # Validazione input
        if not all([current_password, new_password]):
            return Response(
                {"message": "Password corrente e nuova password sono obbligatorie"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if len(new_password) < 6:
            return Response(
                {"message": "La nuova password deve essere di almeno 6 caratteri"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Verifica la password corrente
        if not request.user.check_password(current_password):
            return Response(
                {"message": "Password corrente non corretta"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Imposta la nuova password
        request.user.set_password(new_password)
        request.user.save()
        
        return Response({
            "message": "Password cambiata con successo"
        }, status=status.HTTP_200_OK)
        
    except PermissionDenied as e:
        return Response(
            {"message": str(e)},
            status=status.HTTP_403_FORBIDDEN
        )
    except Exception as e:
        logger.error(f"Password change failed: {e}")
        return Response(
            {"message": "Errore durante il cambio password"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([AllowAny])
def request_password_reset(request):
    """Richiedi reset password - invia email con token sicuro"""
    try:
        data = request.data
        email = data.get('email', '').strip().lower()
        
        # Validazione input
        if not email:
            return Response(
                {"message": "Email obbligatoria"},
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
        
        # Cerca l'utente per email
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            # Per sicurezza, non rivelare se l'email esiste o meno
            return Response(
                {"message": "Se l'email esiste, riceverai le istruzioni per il reset"},
                status=status.HTTP_200_OK
            )
        
        # Genera token sicuro per il reset
        reset_token = secrets.token_urlsafe(32)
        reset_token_hash = hashlib.sha256(reset_token.encode()).hexdigest()
        
        # Salva il token nel database con scadenza (1 ora)
        from .models import PasswordResetToken
        PasswordResetToken.objects.filter(user=user).delete()  # Elimina token precedenti
        PasswordResetToken.objects.create(
            user=user,
            token_hash=reset_token_hash,
            expires_at=timezone.now() + timedelta(hours=1)
        )
        
        # TODO: Invia email con il token (implementare servizio email)
        # Per ora, logghiamo il token per il test (NON FARE IN PRODUZIONE!)
        logger.info(f"Password reset token for {email}: {reset_token}")
        
        from django.conf import settings
        return Response({
            "message": "Se l'email esiste, riceverai le istruzioni per il reset",
            "debug_token": reset_token if settings.DEBUG else None  # Solo per debug
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Password reset request failed: {e}")
        return Response(
            {"message": "Errore durante la richiesta di reset"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([AllowAny])
def reset_password(request):
    """Reset password con email e user ID (nuovo flusso) o token sicuro (flusso legacy)"""
    try:
        data = request.data
        
        # Supporta sia il nuovo flusso (email + user_id) che quello legacy (token)
        email = data.get('email', '').strip().lower()
        user_id = data.get('user_id', '').strip()
        token = data.get('token', '').strip()
        new_password = data.get('new_password', '')
        
        # Validazione input - deve avere nuovo flusso O legacy
        if not new_password:
            return Response(
                {"message": "Nuova password obbligatoria"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if not ((email and user_id) or token):
            return Response(
                {"message": "Email e user ID oppure token sono obbligatori"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if len(new_password) < 6:
            return Response(
                {"message": "La password deve essere di almeno 6 caratteri"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Gestisce due flussi: nuovo (email + user_id) e legacy (token)
        if email and user_id:
            # NUOVO FLUSSO: Verifica email e user_id
            try:
                user = User.objects.get(id=user_id, email=email, is_active=True)
                logger.info(f"Password reset - New flow: User {user.id} ({email}) found")
            except User.DoesNotExist:
                return Response(
                    {"message": "Utente non trovato o email non corrispondente"},
                    status=status.HTTP_400_BAD_REQUEST
                )
        else:
            # FLUSSO LEGACY: Verifica il token
            token_hash = hashlib.sha256(token.encode()).hexdigest()
            try:
                from .models import PasswordResetToken
                reset_token = PasswordResetToken.objects.get(
                    token_hash=token_hash,
                    expires_at__gt=timezone.now(),
                    is_used=False
                )
                user = reset_token.user
                
                # Invalida il token
                reset_token.is_used = True
                reset_token.save()
                
                logger.info(f"Password reset - Legacy flow: User {user.id} with token")
            except PasswordResetToken.DoesNotExist:
                return Response(
                    {"message": "Token non valido o scaduto"},
                    status=status.HTTP_400_BAD_REQUEST
                )
        
        # Aggiorna la password
        user.set_password(new_password)
        user.save()
        
        # Elimina tutti i token di autenticazione esistenti (logout forzato)
        AuthToken.objects.filter(user=user, is_active=True).update(is_active=False)
        
        logger.info(f"Password reset successful for user {user.id}")
        
        return Response({
            "message": "Password resettata con successo"
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"Password reset failed: {e}")
        return Response(
            {"message": "Errore durante il reset password"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

