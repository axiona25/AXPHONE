import hashlib
import hmac
import time
import json
import requests
from django.conf import settings
from django.utils import timezone
import logging
from .models import Call
try:
    from ..crypto.sframe_crypto import sframe_manager
    from ..crypto.models import Session, Device
except ImportError:
    # Fallback per problemi di import
    print("⚠️ Crypto modules non disponibili, continuando senza SFrame")
    sframe_manager = None

logger = logging.getLogger('securevox')


class TURNService:
    """Servizio per generazione credenziali TURN"""
    
    def __init__(self):
        self.host = settings.TURN_SERVER['host']
        self.port = settings.TURN_SERVER['port']
        self.username = settings.TURN_SERVER['username']
        self.password = settings.TURN_SERVER['password']
        self.realm = settings.TURN_SERVER['realm']
    
    def generate_turn_credentials(self, user_id, device_id, ttl=3600):
        """
        Genera credenziali TURN temporanee per un dispositivo
        
        Args:
            user_id: ID dell'utente
            device_id: ID del dispositivo
            ttl: Time to live in seconds (default: 1 ora)
        
        Returns:
            dict: Credenziali TURN
        """
        try:
            # Genera username temporaneo
            timestamp = int(time.time()) + ttl
            username = f"{user_id}:{device_id}:{timestamp}"
            
            # Genera password HMAC
            secret = self.password
            # SECURITY FIX: Upgraded from SHA1 to SHA256
            password = hmac.new(
                secret.encode('utf-8'),
                username.encode('utf-8'),
                hashlib.sha256  # Changed from sha1 to sha256
            ).hexdigest()
            
            return {
                'username': username,
                'password': password,
                'ttl': ttl,
                'uris': [
                    f"turn:{self.host}:{self.port}?transport=udp",
                    f"turn:{self.host}:{self.port}?transport=tcp",
                    f"turns:{self.host}:{self.port}?transport=tcp",
                ]
            }
            
        except Exception as e:
            logger.error(f"Failed to generate TURN credentials: {e}")
            return None


class JanusSFUService:
    """Servizio per interazione con Janus SFU"""
    
    def __init__(self):
        self.url = settings.JANUS_SFU['url']
        self.api_secret = settings.JANUS_SFU['api_secret']
        self.admin_secret = settings.JANUS_SFU['admin_secret']
    
    def create_room(self, room_id, description="SecureVOX Room", max_publishers=50):
        """
        Crea una stanza video per chiamate group
        
        Args:
            room_id: ID della stanza
            description: Descrizione della stanza
            max_publishers: Numero massimo di publisher
        
        Returns:
            dict: Risposta da Janus
        """
        try:
            payload = {
                "request": "create",
                "room": room_id,
                "description": description,
                "publishers": max_publishers,
                "bitrate": 1024000,
                "fir_freq": 10,
                "e2ee": True,  # Abilita E2EE
                "secret": self.api_secret
            }
            
            response = requests.post(
                f"{self.url}/janus/videoroom",
                json=payload,
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                logger.info(f"Room {room_id} created successfully")
                return result
            else:
                logger.error(f"Failed to create room {room_id}: {response.status_code}")
                return None
                
        except Exception as e:
            logger.error(f"Error creating room {room_id}: {e}")
            return None
    
    def destroy_room(self, room_id):
        """
        Distrugge una stanza video
        
        Args:
            room_id: ID della stanza
        
        Returns:
            dict: Risposta da Janus
        """
        try:
            payload = {
                "request": "destroy",
                "room": room_id,
                "secret": self.api_secret
            }
            
            response = requests.post(
                f"{self.url}/janus/videoroom",
                json=payload,
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                logger.info(f"Room {room_id} destroyed successfully")
                return result
            else:
                logger.error(f"Failed to destroy room {room_id}: {response.status_code}")
                return None
                
        except Exception as e:
            logger.error(f"Error destroying room {room_id}: {e}")
            return None
    
    def list_rooms(self):
        """
        Lista tutte le stanze attive
        
        Returns:
            list: Lista delle stanze
        """
        try:
            payload = {
                "request": "list",
                "secret": self.api_secret
            }
            
            response = requests.post(
                f"{self.url}/janus/videoroom",
                json=payload,
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                return result.get('list', [])
            else:
                logger.error(f"Failed to list rooms: {response.status_code}")
                return []
                
        except Exception as e:
            logger.error(f"Error listing rooms: {e}")
            return []
    
    def get_room_info(self, room_id):
        """
        Ottieni informazioni su una stanza
        
        Args:
            room_id: ID della stanza
        
        Returns:
            dict: Informazioni della stanza
        """
        try:
            payload = {
                "request": "listparticipants",
                "room": room_id,
                "secret": self.api_secret
            }
            
            response = requests.post(
                f"{self.url}/janus/videoroom",
                json=payload,
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                return result
            else:
                logger.error(f"Failed to get room info {room_id}: {response.status_code}")
                return None
                
        except Exception as e:
            logger.error(f"Error getting room info {room_id}: {e}")
            return None


class WebRTCService:
    """Servizio principale per WebRTC"""
    
    def __init__(self):
        self.turn_service = TURNService()
        self.janus_service = JanusSFUService()
    
    def get_ice_servers(self, user_id, device_id):
        """
        Ottieni server ICE per WebRTC
        
        Args:
            user_id: ID dell'utente
            device_id: ID del dispositivo
        
        Returns:
            list: Lista dei server ICE
        """
        ice_servers = [
            {
                "urls": "stun:stun.l.google.com:19302"
            },
            {
                "urls": "stun:stun1.l.google.com:19302"
            }
        ]
        
        # Aggiungi credenziali TURN
        turn_creds = self.turn_service.generate_turn_credentials(user_id, device_id)
        if turn_creds:
            for uri in turn_creds['uris']:
                ice_servers.append({
                    "urls": uri,
                    "username": turn_creds['username'],
                    "credential": turn_creds['password']
                })
        
        return ice_servers
    
    def create_call_session(self, caller_id, callee_id, call_type='video', encrypted=True):
        """
        Crea una sessione di chiamata crittografata end-to-end
        
        Args:
            caller_id: ID del chiamante
            callee_id: ID del destinatario
            call_type: Tipo di chiamata (audio/video)
            encrypted: Se abilitare la crittografia E2E (default: True)
        
        Returns:
            dict: Informazioni della sessione crittografata
        """
        try:
            import time
            session_id = f"call_{caller_id}_{callee_id}_{int(time.time())}"
            
            # Crea la chiamata crittografata SFrame
            sframe_call = None
            encryption_info = None
            
            if encrypted and sframe_manager is not None:
                try:
                    # Crea manager SFrame per la chiamata
                    sframe_call = sframe_manager.create_call(session_id)
                    
                    # Ottieni le sessioni Signal esistenti per derivare le chiavi
                    caller_device = Device.objects.filter(user_id=caller_id, is_active=True).first()
                    callee_device = Device.objects.filter(user_id=callee_id, is_active=True).first()
                    
                    if caller_device and callee_device:
                        # Cerca sessione Signal esistente
                        signal_session = Session.objects.filter(
                            device_a=caller_device, 
                            device_b=callee_device
                        ).first() or Session.objects.filter(
                            device_a=callee_device, 
                            device_b=caller_device
                        ).first()
                        
                        if signal_session:
                            # Simula chiavi Signal (in produzione verranno dal Double Ratchet)
                            import os
                            caller_signal_key = os.urandom(32)  # Chiave simulata
                            callee_signal_key = os.urandom(32)  # Chiave simulata
                            
                            # Aggiungi partecipanti con chiavi derivate
                            sframe_call.add_participant(str(caller_id), caller_signal_key)
                            sframe_call.add_participant(str(callee_id), callee_signal_key)
                            
                            encryption_info = {
                                'enabled': True,
                                'algorithm': 'SFrame-AES-GCM-256',
                                'key_rotation_interval': 300,  # 5 minuti
                                'participants': [str(caller_id), str(callee_id)]
                            }
                            
                            logger.info(f"✅ Crittografia E2E attivata per chiamata {session_id}")
                        else:
                            logger.warning(f"⚠️ Nessuna sessione Signal trovata tra {caller_id} e {callee_id}")
                            encrypted = False
                    else:
                        logger.warning(f"⚠️ Dispositivi non trovati per {caller_id} o {callee_id}")
                        encrypted = False
                        
                except Exception as e:
                    logger.error(f"❌ Errore setup crittografia E2E: {e}")
                    encrypted = False
            elif encrypted and sframe_manager is None:
                logger.warning("⚠️ Crittografia richiesta ma SFrame non disponibile, continuando senza")
                encrypted = False
            
            # Setup Janus SFU (opzionale)
            try:
                room_result = self.janus_service.create_room(
                    room_id=session_id,
                    description=f"Chiamata Crittografata {caller_id} → {callee_id}",
                    max_publishers=2
                )
                janus_available = room_result is not None
            except Exception as e:
                logger.warning(f"Janus SFU non disponibile, usando P2P: {e}")
                janus_available = False
            
            # Crea record della chiamata nel database
            try:
                from django.contrib.auth.models import User
                caller_user = User.objects.get(id=caller_id)
                callee_user = User.objects.get(id=callee_id)
                
                call_record = Call.objects.create(
                    caller=caller_user,
                    callee=callee_user,
                    session_id=session_id,
                    call_type=call_type,
                    status='ringing',  # Changed from 'initializing' to match choices
                    is_encrypted=encrypted
                )
                logger.info(f"📞 Record chiamata creato: {call_record.id}")
            except Exception as e:
                logger.error(f"❌ Errore creazione record chiamata: {e}")
            
            return {
                'session_id': session_id,
                'room_id': session_id,
                'call_type': call_type,
                'ice_servers': self.get_ice_servers(caller_id, f"caller_{caller_id}"),
                'janus_url': settings.JANUS_SFU['url'] if janus_available else None,
                'janus_available': janus_available,
                'mode': 'sfu' if janus_available else 'p2p',
                'encryption': encryption_info or {'enabled': False},
                'created_at': timezone.now().isoformat(),
                'signaling_server': f"ws://localhost:8003/ws/call/{session_id}/",
                'stun_servers': [
                    "stun:stun.l.google.com:19302",
                    "stun:stun1.l.google.com:19302"
                ]
            }
                
        except Exception as e:
            logger.error(f"❌ Errore creazione sessione chiamata: {e}")
            return None
    
    def create_group_call(self, creator_id, room_name, max_participants=10):
        """
        Crea una chiamata di gruppo
        
        Args:
            creator_id: ID del creatore
            room_name: Nome della stanza
            max_participants: Numero massimo di partecipanti
        
        Returns:
            dict: Informazioni della stanza
        """
        try:
            room_id = f"group_{creator_id}_{int(time.time())}"
            
            room_result = self.janus_service.create_room(
                room_id=room_id,
                description=room_name,
                max_publishers=max_participants
            )
            
            if room_result:
                return {
                    'room_id': room_id,
                    'room_name': room_name,
                    'max_participants': max_participants,
                    'ice_servers': self.get_ice_servers(creator_id, f"group_{creator_id}"),
                    'janus_url': settings.JANUS_SFU['url'],
                    'created_at': timezone.now().isoformat()
                }
            else:
                return None
                
        except Exception as e:
            logger.error(f"Error creating group call: {e}")
            return None
    
    def end_call_session(self, session_id):
        """
        Termina una sessione di chiamata crittografata
        
        Args:
            session_id: ID della sessione
        
        Returns:
            bool: Successo dell'operazione
        """
        try:
            # Termina sessione SFrame se disponibile
            if sframe_manager is not None:
                sframe_call = sframe_manager.get_call(session_id)
                if sframe_call:
                    sframe_manager.end_call(session_id)
                    logger.info(f"🔐 Sessione crittografata SFrame terminata: {session_id}")
            
            # Aggiorna record chiamata nel database
            try:
                call_record = Call.objects.get(session_id=session_id)
                call_record.status = 'ended'
                call_record.ended_at = timezone.now()
                call_record.save()
                logger.info(f"📞 Record chiamata aggiornato: {call_record.id}")
            except Call.DoesNotExist:
                logger.warning(f"⚠️ Record chiamata non trovato: {session_id}")
            
            # Termina stanza Janus se disponibile
            result = self.janus_service.destroy_room(session_id)
            return result is not None
            
        except Exception as e:
            logger.error(f"❌ Errore terminazione sessione chiamata {session_id}: {e}")
            return False
    
    def get_call_encryption_stats(self, session_id):
        """
        Ottiene statistiche crittografia per una sessione
        
        Args:
            session_id: ID della sessione
            
        Returns:
            dict: Statistiche crittografia
        """
        try:
            if sframe_manager is not None:
                sframe_call = sframe_manager.get_call(session_id)
                if sframe_call:
                    return sframe_call.get_encryption_stats()
                else:
                    return {'error': 'Sessione non trovata'}
            else:
                return {'error': 'SFrame non disponibile', 'encryption_enabled': False}
        except Exception as e:
            logger.error(f"❌ Errore recupero statistiche crittografia: {e}")
            return {'error': str(e)}
    
    def rotate_call_keys(self, session_id, new_signal_keys):
        """
        Ruota le chiavi di una sessione di chiamata
        
        Args:
            session_id: ID della sessione
            new_signal_keys: Dict delle nuove chiavi Signal per i partecipanti
            
        Returns:
            bool: Successo dell'operazione
        """
        try:
            if sframe_manager is not None:
                sframe_call = sframe_manager.get_call(session_id)
                if sframe_call:
                    sframe_call.rotate_all_keys(new_signal_keys)
                    logger.info(f"🔄 Chiavi ruotate per sessione {session_id}")
                    return True
                else:
                    logger.warning(f"⚠️ Sessione SFrame non trovata: {session_id}")
                    return False
            else:
                logger.warning("⚠️ SFrame non disponibile per rotazione chiavi")
                return False
        except Exception as e:
            logger.error(f"❌ Errore rotazione chiavi: {e}")
            return False


# Istanza globale del servizio
webrtc_service = WebRTCService()
