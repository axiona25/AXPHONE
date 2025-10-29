"""
API Views per End-to-End Encryption (E2EE)
Gestisce lo scambio delle chiavi pubbliche tra utenti
"""

from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.authentication import TokenAuthentication
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.contrib.auth.models import User
from .models import UserStatus


@api_view(['POST'])
@authentication_classes([TokenAuthentication])
@permission_classes([IsAuthenticated])
def upload_public_key(request):
    """
    Upload della chiave pubblica E2EE dell'utente
    
    POST /api/e2e/upload-key/
    Body: {
        "public_key": "12345678901234567890..."
    }
    """
    try:
        user = request.user
        public_key = request.data.get('public_key')
        
        if not public_key:
            return Response({
                'error': 'public_key è richiesta'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Ottieni o crea UserStatus
        user_status, created = UserStatus.objects.get_or_create(user=user)
        
        # Salva la chiave pubblica
        user_status.e2e_public_key = public_key
        user_status.save()
        
        print(f'🔐 E2EE: Chiave pubblica salvata per utente {user.username} (ID: {user.id})')
        print(f'🔐 E2EE: Lunghezza chiave: {len(public_key)} caratteri')
        
        return Response({
            'status': 'success',
            'message': 'Chiave pubblica salvata con successo',
            'user_id': user.id,
            'key_length': len(public_key)
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        print(f'❌ E2EE: Errore upload chiave pubblica: {e}')
        return Response({
            'error': f'Errore durante il salvataggio: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@authentication_classes([TokenAuthentication])
@permission_classes([IsAuthenticated])
def get_user_public_key(request, user_id):
    """
    Recupera la chiave pubblica di un utente specifico
    
    GET /api/e2e/get-key/<user_id>/
    """
    try:
        # Verifica che l'utente esista
        try:
            target_user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response({
                'error': 'Utente non trovato'
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Ottieni UserStatus
        try:
            user_status = UserStatus.objects.get(user=target_user)
        except UserStatus.DoesNotExist:
            return Response({
                'error': 'Chiave pubblica non disponibile'
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Verifica che abbia una chiave pubblica
        if not user_status.e2e_public_key:
            return Response({
                'error': 'Chiave pubblica non configurata per questo utente'
            }, status=status.HTTP_404_NOT_FOUND)
        
        print(f'🔐 E2EE: Chiave pubblica richiesta per utente {target_user.username} (ID: {user_id})')
        
        return Response({
            'user_id': user_id,
            'username': target_user.username,
            'public_key': user_status.e2e_public_key,
            'key_length': len(user_status.e2e_public_key)
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        print(f'❌ E2EE: Errore recupero chiave pubblica: {e}')
        return Response({
            'error': f'Errore durante il recupero: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@authentication_classes([TokenAuthentication])
@permission_classes([IsAuthenticated])
def get_my_public_key(request):
    """
    Recupera la propria chiave pubblica
    
    GET /api/e2e/my-key/
    """
    try:
        user = request.user
        
        # Ottieni UserStatus
        try:
            user_status = UserStatus.objects.get(user=user)
        except UserStatus.DoesNotExist:
            return Response({
                'error': 'Chiave pubblica non configurata',
                'has_key': False
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Verifica che abbia una chiave pubblica
        if not user_status.e2e_public_key:
            return Response({
                'error': 'Chiave pubblica non configurata',
                'has_key': False
            }, status=status.HTTP_404_NOT_FOUND)
        
        return Response({
            'user_id': user.id,
            'username': user.username,
            'public_key': user_status.e2e_public_key,
            'key_length': len(user_status.e2e_public_key),
            'has_key': True
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        print(f'❌ E2EE: Errore recupero chiave pubblica personale: {e}')
        return Response({
            'error': f'Errore durante il recupero: {str(e)}',
            'has_key': False
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@authentication_classes([TokenAuthentication])
@permission_classes([IsAuthenticated])
def get_multiple_keys(request):
    """
    Recupera le chiavi pubbliche di più utenti in una singola richiesta
    
    POST /api/e2e/get-keys/
    Body: {
        "user_ids": [1, 2, 3, 4]
    }
    """
    try:
        user_ids = request.data.get('user_ids', [])
        
        if not user_ids or not isinstance(user_ids, list):
            return Response({
                'error': 'user_ids deve essere una lista di ID'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        print(f'🔐 E2EE: Richiesta chiavi per {len(user_ids)} utenti')
        
        # Recupera tutte le chiavi in una query
        user_statuses = UserStatus.objects.filter(
            user__id__in=user_ids,
            e2e_public_key__isnull=False
        ).select_related('user')
        
        # Costruisci risposta
        keys = {}
        for user_status in user_statuses:
            keys[str(user_status.user.id)] = {
                'user_id': user_status.user.id,
                'username': user_status.user.username,
                'public_key': user_status.e2e_public_key
            }
        
        print(f'🔐 E2EE: Trovate {len(keys)} chiavi su {len(user_ids)} richieste')
        
        return Response({
            'keys': keys,
            'found': len(keys),
            'requested': len(user_ids)
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        print(f'❌ E2EE: Errore recupero chiavi multiple: {e}')
        return Response({
            'error': f'Errore durante il recupero: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@authentication_classes([TokenAuthentication])
@permission_classes([IsAuthenticated])
def get_my_e2e_status(request):
    """
    Recupera lo stato E2EE dell'utente corrente (incluso force_disabled)
    
    GET /api/e2e/my-status/
    Returns: {
        "e2e_enabled": bool,
        "e2e_force_disabled": bool,
        "has_public_key": bool
    }
    """
    try:
        user = request.user
        
        # Ottieni o crea UserStatus
        user_status, created = UserStatus.objects.get_or_create(
            user=user,
            defaults={
                'status': 'offline',
                'e2e_enabled': False,
                'e2e_force_disabled': False,
            }
        )
        
        return Response({
            'user_id': user.id,
            'username': user.username,
            'e2e_enabled': user_status.e2e_enabled,
            'e2e_force_disabled': user_status.e2e_force_disabled,
            'has_public_key': bool(user_status.e2e_public_key),
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        print(f'❌ E2EE: Errore recupero stato E2EE: {e}')
        return Response({
            'error': f'Errore durante il recupero: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

