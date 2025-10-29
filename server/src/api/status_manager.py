"""
Sistema di gestione stati utente per SecureVox
Gestisce login/logout e stati online/offline in tempo reale

REGOLE TOKEN:
- 1 utente = 1 token (Token DRF standard)
- 1 login = elimina token precedente + crea nuovo token
- Token NON scade mai (valido fino a logout)
- STESSO token per TUTTI i servizi
"""
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.authtoken.models import Token
from .models import UserStatus
import logging

logger = logging.getLogger('securevox')


class UserStatusManager:
    """Manager per gestire gli stati degli utenti"""
    
    @staticmethod
    def create_user_session(user):
        """
        Crea una nuova sessione per l'utente (login)
        
        REGOLE:
        - 1 utente = 1 token
        - 1 login = elimina token precedente e genera nuovo token
        - Token NON scade mai (valido fino a logout)
        - STESSO token per TUTTI i servizi
        """
        try:
            # ELIMINA token precedente (se esiste)
            # Questo garantisce che ci sia SEMPRE E SOLO UN token per utente
            Token.objects.filter(user=user).delete()
            logger.info(f"🔐 Token precedente eliminato per {user.username} (se esisteva)")
            
            # CREA nuovo token DRF standard
            # Questo è l'UNICO token che l'utente avrà
            token = Token.objects.create(user=user)
            logger.info(f"✅ NUOVO token creato per {user.username}: {token.key[:20]}...")
            
            # Aggiorna/crea stato utente
            user_status, created = UserStatus.objects.get_or_create(user=user)
            user_status.set_online(token.key)
            
            logger.info(f"🔐 Sessione creata - User {user.id} ({user.username}) impostato ONLINE")
            
            # RITORNA SEMPRE E SOLO IL TOKEN STANDARD
            return {
                'auth_token': token.key,  # Stesso token
                'standard_token': token.key,  # Stesso token
                'status': 'online'
            }
            
        except Exception as e:
            logger.error(f"Errore creazione sessione per user {user.id}: {e}")
            raise
    
    @staticmethod
    def destroy_user_session(user):
        """
        Distrugge la sessione dell'utente (logout)
        
        REGOLE:
        - Elimina l'UNICO token dell'utente
        - Imposta stato offline
        """
        try:
            # ELIMINA l'unico token dell'utente
            deleted_count = Token.objects.filter(user=user).delete()[0]
            logger.info(f"🔐 Token eliminato per {user.username} (count: {deleted_count})")
            
            # Aggiorna stato utente come offline
            try:
                user_status = UserStatus.objects.get(user=user)
                user_status.set_offline()
                logger.info(f"🔐 Sessione distrutta - User {user.id} ({user.username}) impostato OFFLINE")
            except UserStatus.DoesNotExist:
                logger.warning(f"Nessuno stato da aggiornare per user {user.id}")
            
            return True
            
        except Exception as e:
            logger.error(f"Errore distruzione sessione per user {user.id}: {e}")
            raise
    
    @staticmethod
    def update_user_activity(user, has_connection=True):
        """Aggiorna l'attività dell'utente (heartbeat)"""
        try:
            user_status, created = UserStatus.objects.get_or_create(user=user)
            
            # Verifica se ha ancora un token valido
            if user_status.is_active_session():
                if has_connection:
                    user_status.update_status('online', True)
                else:
                    user_status.set_unreachable()
            else:
                # Token non più valido, imposta offline
                user_status.set_offline()
            
            return user_status.status
            
        except Exception as e:
            logger.error(f"Errore aggiornamento attività per user {user.id}: {e}")
            return 'offline'
    
    @staticmethod
    def get_all_users_status():
        """Ottiene lo stato di tutti gli utenti con logica corretta"""
        try:
            users = User.objects.filter(is_active=True).select_related('status_info')
            status_data = []
            
            for user in users:
                try:
                    # Ottieni o crea stato utente
                    user_status, created = UserStatus.objects.get_or_create(user=user)
                    
                    # LOGICA CORRETTA: Verifica se la sessione è ancora attiva
                    if user_status.is_active_session():
                        # Ha token valido = è loggato
                        is_logged_in = True
                        
                        # Determina se ha connessione basato su ultima attività (più conservativo)
                        time_since_activity = timezone.now() - user_status.last_activity
                        has_connection = time_since_activity.total_seconds() < 120  # 2 minuti (più stretto)
                        
                        # LOGICA CORRETTA:
                        # - Loggato + connessione = online (verde)
                        # - Loggato + no connessione = unreachable (giallo)
                        if has_connection:
                            status = 'online'
                        else:
                            status = 'unreachable'
                            
                        logger.debug(f"User {user.id}: logged_in=True, connection={has_connection}, status={status}")
                        
                    else:
                        # Nessun token valido = non loggato
                        is_logged_in = False
                        has_connection = False
                        status = 'offline'  # Grigio
                        
                        # Aggiorna il database se necessario
                        if user_status.status != 'offline':
                            user_status.set_offline()
                            logger.info(f"User {user.id} aggiornato a offline (token scaduto)")
                    
                    status_data.append({
                        'id': user.id,
                        'name': user.username,
                        'is_logged_in': is_logged_in,
                        'has_connection': has_connection,
                        'last_seen': user_status.last_seen.isoformat(),
                        'status': status
                    })
                    
                except Exception as e:
                    logger.error(f"Errore stato per user {user.id}: {e}")
                    # Fallback: utente offline
                    status_data.append({
                        'id': user.id,
                        'name': user.username,
                        'is_logged_in': False,
                        'has_connection': False,
                        'last_seen': timezone.now().isoformat(),
                        'status': 'offline'
                    })
            
            logger.debug(f"Stati recuperati per {len(status_data)} utenti")
            return status_data
            
        except Exception as e:
            logger.error(f"Errore recupero stati utenti: {e}")
            return []
    
    @staticmethod
    def cleanup_expired_sessions():
        """Pulisce le sessioni scadute (task periodico)"""
        try:
            # Trova utenti con stato online ma senza token validi
            online_users = UserStatus.objects.filter(is_logged_in=True)
            cleaned = 0
            
            for user_status in online_users:
                if not user_status.is_active_session():
                    user_status.set_offline()
                    cleaned += 1
                    logger.info(f"Sessione scaduta pulita per user {user_status.user.id}")
            
            if cleaned > 0:
                logger.info(f"Pulite {cleaned} sessioni scadute")
            
            return cleaned
            
        except Exception as e:
            logger.error(f"Errore pulizia sessioni: {e}")
            return 0
    
    @staticmethod
    def get_user_status(user_id):
        """Ottiene lo stato di un singolo utente"""
        try:
            user = User.objects.get(id=user_id)
            user_status, created = UserStatus.objects.get_or_create(user=user)
            
            # Verifica se la sessione è ancora attiva
            if user_status.is_active_session():
                return {
                    'id': user.id,
                    'status': user_status.status,
                    'is_logged_in': True,
                    'has_connection': user_status.has_connection,
                    'last_seen': user_status.last_seen.isoformat()
                }
            else:
                # Sessione scaduta, aggiorna come offline
                if user_status.status != 'offline':
                    user_status.set_offline()
                
                return {
                    'id': user.id,
                    'status': 'offline',
                    'is_logged_in': False,
                    'has_connection': False,
                    'last_seen': user_status.last_seen.isoformat()
                }
                
        except User.DoesNotExist:
            return None
        except Exception as e:
            logger.error(f"Errore recupero stato user {user_id}: {e}")
            return None
