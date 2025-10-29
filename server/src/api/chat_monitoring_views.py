"""
Chat Monitoring Views - Admin Dashboard
Endpoint per monitorare chat, messaggi cifrati e notifiche in tempo reale
"""

from django.db.models import Count, Q
from django.utils import timezone
from datetime import timedelta
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from rest_framework.response import Response
from rest_framework import status

from .models import User, Chat, ChatMessage, UserStatus, Call


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsAdminUser])
def chat_statistics(request):
    """
    Statistiche generali per la dashboard chat
    
    Returns:
        - total_users_with_chats: Numero totale di utenti che hanno almeno una chat
        - total_chats: Numero totale di chat nel sistema
        - total_messages: Numero totale di messaggi creati
        - total_notifications: Stima delle notifiche (1 per messaggio inviato)
        - messages_today: Messaggi inviati oggi
        - active_users_today: Utenti attivi oggi
    """
    try:
        # Totale utenti con almeno una chat (creata o come partecipante)
        users_with_any_chat = set()
        
        # Utenti che hanno creato almeno una chat
        users_with_any_chat.update(Chat.objects.values_list('created_by_id', flat=True).distinct())
        
        # Utenti che sono partecipanti di almeno una chat
        users_with_any_chat.update(Chat.objects.values_list('participants__id', flat=True).distinct())
        
        users_with_chats = len([uid for uid in users_with_any_chat if uid is not None])
        
        # Totale chat
        total_chats = Chat.objects.count()
        
        # Totale messaggi
        total_messages = ChatMessage.objects.count()
        
        # Totale notifiche (stimato: 1 notifica per messaggio)
        # In realtà le notifiche sono gestite dal notify server e non sono nel DB
        total_notifications = total_messages
        
        # Messaggi inviati oggi
        today_start = timezone.now().replace(hour=0, minute=0, second=0, microsecond=0)
        messages_today = ChatMessage.objects.filter(created_at__gte=today_start).count()
        
        # Utenti attivi oggi (che hanno inviato almeno un messaggio)
        active_users_today = User.objects.filter(
            sent_messages__created_at__gte=today_start
        ).distinct().count()
        
        # Messaggi cifrati (controllando se E2EE è attivo)
        encrypted_messages = ChatMessage.objects.filter(
            is_encrypted=True
        ).count() if hasattr(ChatMessage, 'is_encrypted') else 0
        
        return Response({
            'total_users_with_chats': users_with_chats,
            'total_chats': total_chats,
            'total_messages': total_messages,
            'total_notifications': total_notifications,
            'messages_today': messages_today,
            'active_users_today': active_users_today,
            'encrypted_messages': encrypted_messages,
            'encryption_percentage': round((encrypted_messages / total_messages * 100), 2) if total_messages > 0 else 0,
        })
    except Exception as e:
        return Response(
            {'error': f'Errore nel recupero delle statistiche: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsAdminUser])
def users_list(request):
    """
    Lista di tutti gli utenti del sistema con informazioni base
    
    Returns:
        Lista utenti con: id, username, email, full_name, date_joined, 
        is_active, total_chats, total_messages
    """
    try:
        from django.db.models.functions import Coalesce
        from django.db.models import IntegerField
        
        users = User.objects.all().annotate(
            chats_as_participant=Count('chats', distinct=True),
            chats_as_creator=Count('created_chats', distinct=True),
            total_messages=Count('sent_messages', distinct=True)
        ).order_by('-date_joined')
        
        users_data = []
        for user in users:
            # Recupera lo status se esiste
            try:
                user_status = UserStatus.objects.get(user=user)
                is_online = user_status.status == 'online' and user_status.is_logged_in
                last_seen = user_status.last_seen
                e2e_enabled = user_status.e2e_enabled and not user_status.e2e_force_disabled
                e2e_has_key = bool(user_status.e2e_public_key)
                e2e_force_disabled = user_status.e2e_force_disabled
            except UserStatus.DoesNotExist:
                is_online = False
                last_seen = None
                e2e_enabled = False
                e2e_has_key = False
                e2e_force_disabled = False
            
            # Costruisce full_name da first_name e last_name
            full_name = f"{user.first_name} {user.last_name}".strip()
            if not full_name:
                full_name = user.username
            
            # Ottieni l'avatar_url dal profilo se esiste
            avatar_url = ''
            try:
                if hasattr(user, 'profile') and user.profile.avatar_url:
                    avatar_url = user.profile.avatar_url
            except Exception:
                pass
            
            users_data.append({
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'full_name': full_name,
                'first_name': user.first_name or '',
                'last_name': user.last_name or '',
                'date_joined': user.date_joined,
                'is_active': user.is_active,
                'is_online': is_online,
                'last_seen': last_seen,
                'total_chats': user.chats_as_participant + user.chats_as_creator,
                'total_messages': user.total_messages,
                'e2e_enabled': e2e_enabled,
                'e2e_has_key': e2e_has_key,
                'e2e_force_disabled': e2e_force_disabled,
                'avatar_url': avatar_url,
            })
        
        return Response(users_data)
    except Exception as e:
        return Response(
            {'error': f'Errore nel recupero degli utenti: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsAdminUser])
def user_chats(request, user_id):
    """
    Tutte le chat di un utente specifico
    
    Args:
        user_id: ID dell'utente
        
    Returns:
        Lista delle chat con informazioni sui partecipanti e ultimo messaggio
    """
    try:
        user = User.objects.get(id=user_id)
        
        # Recupera tutte le chat dell'utente (create o a cui partecipa)
        chats = Chat.objects.filter(
            Q(created_by=user) | Q(participants=user)
        ).distinct().order_by('-updated_at')
        
        chats_data = []
        for chat in chats:
            # Recupera l'ultimo messaggio
            last_message = chat.messages.order_by('-created_at').first()
            
            # Recupera i partecipanti con status online/offline
            participants = []
            for participant in chat.participants.all():
                try:
                    participant_status = UserStatus.objects.get(user=participant)
                    is_online = participant_status.status == 'online' and participant_status.is_logged_in
                    last_seen = participant_status.last_seen
                except UserStatus.DoesNotExist:
                    is_online = False
                    last_seen = None
                
                # Costruisce full_name da first_name e last_name
                participant_full_name = f"{participant.first_name} {participant.last_name}".strip()
                if not participant_full_name:
                    participant_full_name = participant.username
                
                # Ottieni l'avatar_url dal profilo se esiste
                participant_avatar = ''
                try:
                    if hasattr(participant, 'profile') and participant.profile.avatar_url:
                        participant_avatar = participant.profile.avatar_url
                except Exception:
                    pass
                
                participants.append({
                    'id': participant.id,
                    'username': participant.username,
                    'full_name': participant_full_name,
                    'email': participant.email,
                    'avatar_url': participant_avatar,
                    'is_online': is_online,
                    'last_seen': last_seen,
                })
            
            # Costruisce full_name del creator
            creator_full_name = f"{chat.created_by.first_name} {chat.created_by.last_name}".strip()
            if not creator_full_name:
                creator_full_name = chat.created_by.username
            
            # Determina se il messaggio è cifrato (E2EE attivo)
            # Nota: ChatMessage non ha campo encrypted_content, 
            # verifichiamo se il contenuto sembra cifrato
            is_encrypted = False
            if last_message:
                # Se il contenuto inizia con caratteri tipici di base64/JSON cifrato
                # oppure contiene pattern tipici di payload cifrato
                content_str = str(last_message.content)
                is_encrypted = (
                    content_str.startswith('{') and 
                    ('ciphertext' in content_str or 'iv' in content_str or 'mac' in content_str)
                )
            
            chats_data.append({
                'id': chat.id,
                'name': chat.name,
                'is_group': chat.is_group,
                'is_encrypted': is_encrypted,  # Indica se la chat ha messaggi cifrati
                'created_at': chat.created_at,
                'updated_at': chat.updated_at,
                'creator': {
                    'id': chat.created_by.id,
                    'username': chat.created_by.username,
                    'full_name': creator_full_name,
                },
                'participants': participants,
                'total_messages': chat.messages.count(),
                'last_message': {
                    'id': last_message.id,
                    'content': last_message.content,
                    'timestamp': last_message.created_at,
                    'sender': last_message.sender.username,
                    'message_type': last_message.message_type,
                    'is_encrypted': is_encrypted,
                } if last_message else None,
            })
        
        # Costruisce full_name dell'utente
        user_full_name = f"{user.first_name} {user.last_name}".strip()
        if not user_full_name:
            user_full_name = user.username
        
        # Recupera lo status E2EE dell'utente
        try:
            user_status = UserStatus.objects.get(user=user)
            e2e_enabled = user_status.e2e_enabled and not user_status.e2e_force_disabled
            e2e_has_key = bool(user_status.e2e_public_key)
            e2e_force_disabled = user_status.e2e_force_disabled
        except UserStatus.DoesNotExist:
            e2e_enabled = False
            e2e_has_key = False
            e2e_force_disabled = False
        
        return Response({
            'user': {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'full_name': user_full_name,
                'e2e_enabled': e2e_enabled,
                'e2e_has_key': e2e_has_key,
                'e2e_force_disabled': e2e_force_disabled,
            },
            'chats': chats_data,
        })
    except User.DoesNotExist:
        return Response(
            {'error': 'Utente non trovato'},
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        return Response(
            {'error': f'Errore nel recupero delle chat: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsAdminUser])
def chat_messages(request, chat_id):
    """
    Tutti i messaggi di una chat specifica in timeline
    
    Args:
        chat_id: ID della chat
        
    Query Parameters:
        limit: Numero massimo di messaggi (default: 100)
        offset: Offset per paginazione (default: 0)
        
    Returns:
        Lista dei messaggi con informazioni su cifratura
        IMPORTANTE: Il contenuto cifrato è visibile solo se E2EE è attivo,
        altrimenti mostra [ENCRYPTED]
    """
    try:
        chat = Chat.objects.get(id=chat_id)
        
        # Paginazione
        limit = int(request.GET.get('limit', 100))
        offset = int(request.GET.get('offset', 0))
        
        # Recupera i messaggi
        messages = chat.messages.order_by('created_at')[offset:offset + limit]
        
        messages_data = []
        for message in messages:
            # Controlla se il messaggio è cifrato
            # Nota: ChatMessage non ha campo encrypted_content,
            # verifichiamo se il contenuto sembra cifrato
            content_str = str(message.content)
            is_encrypted = (
                content_str.startswith('{') and 
                ('ciphertext' in content_str or 'iv' in content_str or 'mac' in content_str)
            )
            
            # IMPORTANTE: Per verificare E2EE, mostriamo se c'è contenuto cifrato
            # ma NON mostriamo il contenuto in chiaro (solo metadata)
            
            # Costruisce full_name del sender
            sender_full_name = f"{message.sender.first_name} {message.sender.last_name}".strip()
            if not sender_full_name:
                sender_full_name = message.sender.username
            
            message_data = {
                'id': message.id,
                'timestamp': message.created_at,
                'sender': {
                    'id': message.sender.id,
                    'username': message.sender.username,
                    'full_name': sender_full_name,
                },
                'message_type': message.message_type,
                'is_encrypted': is_encrypted,
            }
            
            # Se il messaggio è cifrato, mostra il payload cifrato (per verifica)
            if is_encrypted:
                message_data['content'] = '[🔐 ENCRYPTED]'
                # Prova a parsare il JSON cifrato se possibile
                try:
                    import json
                    encrypted_payload = json.loads(content_str)
                    message_data['encrypted_payload'] = {
                        'ciphertext_length': len(encrypted_payload.get('ciphertext', '')),
                        'has_iv': 'iv' in encrypted_payload,
                        'has_mac': 'mac' in encrypted_payload,
                    }
                except:
                    message_data['encrypted_payload'] = {
                        'ciphertext_length': len(content_str),
                        'has_iv': False,
                        'has_mac': False,
                    }
            else:
                # Messaggio in chiaro (legacy o sistema)
                message_data['content'] = message.content[:100] + '...' if len(message.content) > 100 else message.content
                message_data['encrypted_payload'] = None
            
            # Estrai metadata allegati dal campo JSON
            has_attachment = message.message_type in ['image', 'video', 'audio', 'file', 'contact', 'location']
            message_data['has_attachment'] = has_attachment
            
            # Inizializza campi allegati
            message_data['image_url'] = None
            message_data['video_url'] = None
            message_data['file_url'] = None
            message_data['file_name'] = None
            message_data['file_type'] = None
            
            # Se c'è metadata, estrai le informazioni
            if message.metadata:
                metadata = message.metadata if isinstance(message.metadata, dict) else {}
                
                if message.message_type == 'image':
                    message_data['image_url'] = metadata.get('imageUrl') or metadata.get('image_url')
                    message_data['file_name'] = metadata.get('fileName') or metadata.get('file_name') or 'image.jpg'
                    message_data['file_type'] = 'image/jpeg'
                
                elif message.message_type == 'video':
                    message_data['video_url'] = metadata.get('videoUrl') or metadata.get('video_url')
                    message_data['file_name'] = metadata.get('fileName') or metadata.get('file_name') or 'video.mp4'
                    message_data['file_type'] = 'video/mp4'
                
                elif message.message_type in ['file', 'audio']:
                    message_data['file_url'] = metadata.get('fileUrl') or metadata.get('file_url')
                    message_data['file_name'] = metadata.get('fileName') or metadata.get('file_name') or 'file'
                    message_data['file_type'] = metadata.get('fileType') or metadata.get('file_type') or 'application/octet-stream'
                
                elif message.message_type == 'contact':
                    # Contatto dalla rubrica
                    message_data['file_type'] = 'contact'
                    message_data['file_name'] = metadata.get('contactName') or metadata.get('contact_name') or 'Contatto'
                
                elif message.message_type == 'location':
                    # Posizione GPS
                    message_data['file_type'] = 'location'
                    message_data['file_name'] = 'Posizione condivisa'
            
            messages_data.append(message_data)
        
        return Response({
            'chat': {
                'id': chat.id,
                'name': chat.name,
                'is_group': chat.is_group,
            },
            'total_messages': chat.messages.count(),
            'messages': messages_data,
            'limit': limit,
            'offset': offset,
        })
    except Chat.DoesNotExist:
        return Response(
            {'error': 'Chat non trovata'},
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        return Response(
            {'error': f'Errore nel recupero dei messaggi: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsAdminUser])
def block_user(request, user_id):
    """
    Blocca un utente: logout forzato e impedisce accesso futuro
    
    Args:
        user_id: ID dell'utente da bloccare
        
    Returns:
        Conferma blocco utente
    """
    try:
        user = User.objects.get(id=user_id)
        
        # Disattiva l'utente
        user.is_active = False
        user.save()
        
        # Logout forzato: elimina tutti i token
        from .models import AuthToken
        AuthToken.objects.filter(user=user).update(is_active=False)
        
        # Imposta status offline
        try:
            user_status = UserStatus.objects.get(user=user)
            user_status.set_offline()
        except UserStatus.DoesNotExist:
            pass
        
        return Response({
            'message': f'Utente {user.username} bloccato con successo',
            'username': user.username,
            'email': user.email,
            'is_active': user.is_active,
        })
    except User.DoesNotExist:
        return Response(
            {'error': 'Utente non trovato'},
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        return Response(
            {'error': f'Errore nel blocco dell\'utente: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsAdminUser])
def unblock_user(request, user_id):
    """
    Sblocca un utente precedentemente bloccato
    
    Args:
        user_id: ID dell'utente da sbloccare
        
    Returns:
        Conferma sblocco utente
    """
    try:
        user = User.objects.get(id=user_id)
        
        # Riattiva l'utente
        user.is_active = True
        user.save()
        
        return Response({
            'message': f'Utente {user.username} sbloccato con successo',
            'username': user.username,
            'email': user.email,
            'is_active': user.is_active,
        })
    except User.DoesNotExist:
        return Response(
            {'error': 'Utente non trovato'},
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        return Response(
            {'error': f'Errore nello sblocco dell\'utente: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['DELETE'])
@permission_classes([IsAuthenticated, IsAdminUser])
def delete_user(request, user_id):
    """
    Elimina completamente un utente e tutti i suoi dati
    
    Args:
        user_id: ID dell'utente da eliminare
        
    Returns:
        Conferma eliminazione
    """
    try:
        user = User.objects.get(id=user_id)
        username = user.username
        email = user.email
        
        # Elimina tutte le chat create dall'utente
        Chat.objects.filter(created_by=user).delete()
        
        # Rimuovi l'utente da tutte le chat di cui è partecipante
        for chat in Chat.objects.filter(participants=user):
            chat.participants.remove(user)
        
        # Elimina tutti i messaggi dell'utente
        ChatMessage.objects.filter(sender=user).delete()
        
        # Elimina tutti i token
        from .models import AuthToken
        AuthToken.objects.filter(user=user).delete()
        
        # Elimina lo status
        UserStatus.objects.filter(user=user).delete()
        
        # Elimina il profilo se esiste
        try:
            from admin_panel.models import UserProfile
            UserProfile.objects.filter(user=user).delete()
        except:
            pass
        
        # Elimina l'utente
        user.delete()
        
        return Response({
            'message': f'Utente {username} eliminato con successo',
            'username': username,
            'email': email,
        })
    except User.DoesNotExist:
        return Response(
            {'error': 'Utente non trovato'},
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        return Response(
            {'error': f'Errore nell\'eliminazione dell\'utente: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsAdminUser])
def reset_user_password(request, user_id):
    """
    Reset password di un utente
    
    Args:
        user_id: ID dell'utente
        
    Body:
        new_password: Nuova password (opzionale, genera automaticamente se non fornita)
        
    Returns:
        Nuova password generata o conferma
    """
    try:
        user = User.objects.get(id=user_id)
        
        new_password = request.data.get('new_password')
        if not new_password:
            # Genera password casuale
            import secrets
            import string
            alphabet = string.ascii_letters + string.digits
            new_password = ''.join(secrets.choice(alphabet) for i in range(12))
        
        # Imposta la nuova password
        user.set_password(new_password)
        user.save()
        
        return Response({
            'message': f'Password resettata con successo per {user.username}',
            'username': user.username,
            'email': user.email,
            'new_password': new_password,
        })
    except User.DoesNotExist:
        return Response(
            {'error': 'Utente non trovato'},
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        return Response(
            {'error': f'Errore nel reset della password: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsAdminUser])
def toggle_user_e2e(request, user_id):
    """
    Abilita o disabilita E2EE per un utente specifico
    
    Args:
        user_id: ID dell'utente
        
    Body:
        force_disabled: True per disabilitare forzatamente E2EE, False per abilitarlo
        
    Returns:
        Stato aggiornato E2EE dell'utente
    """
    try:
        user = User.objects.get(id=user_id)
        force_disabled = request.data.get('force_disabled', False)
        
        # Ottieni o crea lo UserStatus
        user_status, created = UserStatus.objects.get_or_create(
            user=user,
            defaults={
                'status': 'offline',
                'e2e_enabled': not force_disabled,
                'e2e_force_disabled': force_disabled,
            }
        )
        
        if not created:
            # Aggiorna lo stato E2EE
            user_status.e2e_force_disabled = force_disabled
            user_status.e2e_enabled = not force_disabled
            user_status.save()
        
        # Se disabilitiamo E2EE, rimuovi anche la chiave pubblica
        if force_disabled:
            user_status.e2e_public_key = None
            user_status.save()
        
        return Response({
            'message': f'E2EE {"disabilitato" if force_disabled else "abilitato"} per {user.username}',
            'username': user.username,
            'email': user.email,
            'e2e_enabled': user_status.e2e_enabled,
            'e2e_force_disabled': user_status.e2e_force_disabled,
            'has_public_key': bool(user_status.e2e_public_key),
        })
    except User.DoesNotExist:
        return Response(
            {'error': 'Utente non trovato'},
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        return Response(
            {'error': f'Errore nell\'aggiornamento E2EE: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsAdminUser])
def dashboard_statistics(request):
    """
    Statistiche generali del dashboard admin
    
    Returns:
        Statistiche su visitatori, chat, chiamate, utenti attivi, traffico server, ecc.
    """
    try:
        # Calcola il range di oggi
        today_start = timezone.now().replace(hour=0, minute=0, second=0, microsecond=0)
        
        # Totale utenti (visitatori mensili - approssimazione)
        total_users = User.objects.filter(is_active=True).count()
        
        # Chat create oggi
        chats_today = Chat.objects.filter(created_at__gte=today_start).count()
        
        # Chiamate completate oggi
        calls_today = Call.objects.filter(
            timestamp__gte=today_start,
            status='completed'
        ).count()
        
        # Utenti attivi (online ora o visti nelle ultime 24h)
        yesterday = timezone.now() - timedelta(hours=24)
        active_users = UserStatus.objects.filter(
            Q(status='online', is_logged_in=True) | 
            Q(last_seen__gte=yesterday)
        ).count()
        
        # Traffico server per gli ultimi 7 giorni
        server_traffic = []
        for i in range(6, -1, -1):
            day_start = today_start - timedelta(days=i)
            day_end = day_start + timedelta(days=1)
            
            # Conta messaggi + chiamate come "traffico"
            messages_count = ChatMessage.objects.filter(
                created_at__gte=day_start,
                created_at__lt=day_end
            ).count()
            
            calls_count = Call.objects.filter(
                timestamp__gte=day_start,
                timestamp__lt=day_end
            ).count()
            
            traffic_value = messages_count + (calls_count * 5)  # Peso maggiore per chiamate
            
            # Nome del giorno
            day_names = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom']
            day_name = day_names[day_start.weekday()]
            
            server_traffic.append({
                'day': day_name,
                'value': traffic_value
            })
        
        # Informazioni server (mock - in futuro da sistema reale)
        servers = [
            {
                'id': '1',
                'country': '🇮🇹 Italia',
                'domain': 'axphone-it.securevox.com',
                'storage': '85%',
                'status': 'active',
                'page_load': '1.2s',
                'report': 'Ottimale'
            },
            {
                'id': '2',
                'country': '🇩🇪 Germania',
                'domain': 'axphone-de.securevox.com',
                'storage': '62%',
                'status': 'active',
                'page_load': '0.9s',
                'report': 'Ottimale'
            },
            {
                'id': '3',
                'country': '🇺🇸 USA',
                'domain': 'axphone-us.securevox.com',
                'storage': '71%',
                'status': 'active',
                'page_load': '1.5s',
                'report': 'Buono'
            }
        ]
        
        return Response({
            'monthly_visitors': total_users,
            'chats_today': chats_today,
            'calls_today': calls_today,
            'active_users': active_users,
            'server_traffic': server_traffic,
            'servers': servers
        })
    except Exception as e:
        return Response(
            {'error': f'Errore nel recupero delle statistiche dashboard: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

