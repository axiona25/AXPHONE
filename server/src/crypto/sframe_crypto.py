"""
SFrame (Secure Frame) Encryption for WebRTC Media
Implements draft-ietf-sframe-enc for E2E encrypted calls
"""

import os
import struct
import hmac
import hashlib
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend
from typing import Dict, List, Optional, Tuple
import logging

logger = logging.getLogger('securevox.sframe')

class SFrameKeyManager:
    """
    Gestisce le chiavi SFrame per crittografia E2E dei media WebRTC
    """
    
    def __init__(self):
        self.encryption_keys: Dict[str, bytes] = {}  # participant_id -> key
        self.key_ids: Dict[str, int] = {}  # participant_id -> key_id
        self.current_key_id = 0
        
    def derive_key_from_signal_session(self, signal_session_key: bytes, participant_id: str, 
                                     context: str = "SFrame-Key") -> bytes:
        """
        Deriva una chiave SFrame dalla sessione Signal Double Ratchet
        
        Args:
            signal_session_key: Chiave dalla sessione Signal
            participant_id: ID del partecipante
            context: Contesto per la derivazione
            
        Returns:
            bytes: Chiave SFrame derivata
        """
        try:
            # Usa HKDF per derivare la chiave SFrame
            salt = f"sframe-{participant_id}".encode('utf-8')
            info = context.encode('utf-8')
            
            hkdf = HKDF(
                algorithm=hashes.SHA256(),
                length=32,  # 256 bit key
                salt=salt,
                info=info,
                backend=default_backend()
            )
            
            sframe_key = hkdf.derive(signal_session_key)
            
            # Memorizza la chiave
            self.encryption_keys[participant_id] = sframe_key
            self.key_ids[participant_id] = self.current_key_id
            self.current_key_id += 1
            
            logger.info(f"Derived SFrame key for participant {participant_id}")
            return sframe_key
            
        except Exception as e:
            logger.error(f"Failed to derive SFrame key: {e}")
            raise
    
    def rotate_key(self, participant_id: str, new_signal_key: bytes) -> bytes:
        """
        Ruota la chiave SFrame per un partecipante
        
        Args:
            participant_id: ID del partecipante
            new_signal_key: Nuova chiave dalla sessione Signal
            
        Returns:
            bytes: Nuova chiave SFrame
        """
        logger.info(f"Rotating SFrame key for participant {participant_id}")
        return self.derive_key_from_signal_session(new_signal_key, participant_id, "SFrame-Rotate")
    
    def get_key(self, participant_id: str) -> Optional[bytes]:
        """Ottiene la chiave per un partecipante"""
        return self.encryption_keys.get(participant_id)
    
    def get_key_id(self, participant_id: str) -> Optional[int]:
        """Ottiene l'ID della chiave per un partecipante"""
        return self.key_ids.get(participant_id)


class SFrameEncryptor:
    """
    Implementa la crittografia SFrame per frame RTP
    """
    
    def __init__(self, key_manager: SFrameKeyManager):
        self.key_manager = key_manager
        self.frame_counter = 0
        
    def encrypt_frame(self, plaintext_frame: bytes, participant_id: str, 
                     media_type: str = "video") -> bytes:
        """
        Cripta un frame RTP usando SFrame
        
        Args:
            plaintext_frame: Frame non crittato
            participant_id: ID del mittente
            media_type: Tipo di media (video/audio)
            
        Returns:
            bytes: Frame crittato con header SFrame
        """
        try:
            key = self.key_manager.get_key(participant_id)
            key_id = self.key_manager.get_key_id(participant_id)
            
            if not key or key_id is None:
                raise ValueError(f"No encryption key for participant {participant_id}")
            
            # Genera IV unico
            iv = os.urandom(12)  # 96-bit IV per AES-GCM
            
            # Crea header SFrame
            sframe_header = self._create_sframe_header(key_id, self.frame_counter)
            
            # Cripta il payload
            cipher = Cipher(algorithms.AES(key), modes.GCM(iv), backend=default_backend())
            encryptor = cipher.encryptor()
            
            # Additional Authenticated Data include header SFrame
            encryptor.authenticate_additional_data(sframe_header)
            
            ciphertext = encryptor.update(plaintext_frame) + encryptor.finalize()
            tag = encryptor.tag
            
            # Costruisce il frame finale: Header SFrame + IV + Ciphertext + Tag
            encrypted_frame = sframe_header + iv + ciphertext + tag
            
            self.frame_counter += 1
            
            logger.debug(f"Encrypted frame for {participant_id}: {len(encrypted_frame)} bytes")
            return encrypted_frame
            
        except Exception as e:
            logger.error(f"Frame encryption failed: {e}")
            raise
    
    def decrypt_frame(self, encrypted_frame: bytes, participant_id: str) -> bytes:
        """
        Decripta un frame SFrame
        
        Args:
            encrypted_frame: Frame crittato
            participant_id: ID del mittente
            
        Returns:
            bytes: Frame decrittato
        """
        try:
            key = self.key_manager.get_key(participant_id)
            if not key:
                raise ValueError(f"No decryption key for participant {participant_id}")
            
            # Parse header SFrame (semplificato - 2 bytes)
            if len(encrypted_frame) < 30:  # Header + IV + Tag minimo
                raise ValueError("Frame too short for SFrame")
            
            header_len = 2  # Header SFrame semplificato
            sframe_header = encrypted_frame[:header_len]
            iv = encrypted_frame[header_len:header_len + 12]
            ciphertext_and_tag = encrypted_frame[header_len + 12:]
            
            if len(ciphertext_and_tag) < 16:  # Minimo per tag GCM
                raise ValueError("Invalid ciphertext length")
            
            ciphertext = ciphertext_and_tag[:-16]
            tag = ciphertext_and_tag[-16:]
            
            # Decripta
            cipher = Cipher(algorithms.AES(key), modes.GCM(iv, tag), backend=default_backend())
            decryptor = cipher.decryptor()
            decryptor.authenticate_additional_data(sframe_header)
            
            plaintext = decryptor.update(ciphertext) + decryptor.finalize()
            
            logger.debug(f"Decrypted frame from {participant_id}: {len(plaintext)} bytes")
            return plaintext
            
        except Exception as e:
            logger.error(f"Frame decryption failed: {e}")
            raise
    
    def _create_sframe_header(self, key_id: int, frame_counter: int) -> bytes:
        """
        Crea header SFrame (versione semplificata)
        
        Args:
            key_id: ID della chiave
            frame_counter: Contatore del frame
            
        Returns:
            bytes: Header SFrame
        """
        # Header semplificato: 1 byte key_id + 1 byte counter (low bits)
        header = struct.pack('BB', key_id & 0xFF, frame_counter & 0xFF)
        return header


class SFrameCallManager:
    """
    Gestisce le chiavi SFrame per una chiamata
    """
    
    def __init__(self, call_id: str):
        self.call_id = call_id
        self.key_manager = SFrameKeyManager()
        self.encryptors: Dict[str, SFrameEncryptor] = {}  # participant_id -> encryptor
        self.participants: List[str] = []
        
    def add_participant(self, participant_id: str, signal_session_key: bytes):
        """
        Aggiunge un partecipante alla chiamata crittata
        
        Args:
            participant_id: ID del partecipante
            signal_session_key: Chiave dalla sessione Signal
        """
        try:
            # Deriva chiave SFrame
            self.key_manager.derive_key_from_signal_session(signal_session_key, participant_id)
            
            # Crea encryptor per il partecipante
            self.encryptors[participant_id] = SFrameEncryptor(self.key_manager)
            
            self.participants.append(participant_id)
            
            logger.info(f"Added participant {participant_id} to encrypted call {self.call_id}")
            
        except Exception as e:
            logger.error(f"Failed to add participant {participant_id}: {e}")
            raise
    
    def remove_participant(self, participant_id: str):
        """Rimuove un partecipante dalla chiamata"""
        if participant_id in self.participants:
            self.participants.remove(participant_id)
            
        if participant_id in self.encryptors:
            del self.encryptors[participant_id]
            
        # Rimuove chiavi
        self.key_manager.encryption_keys.pop(participant_id, None)
        self.key_manager.key_ids.pop(participant_id, None)
        
        logger.info(f"Removed participant {participant_id} from call {self.call_id}")
    
    def encrypt_media_frame(self, frame: bytes, sender_id: str, media_type: str) -> bytes:
        """Cripta un frame media"""
        if sender_id not in self.encryptors:
            raise ValueError(f"No encryptor for participant {sender_id}")
        
        return self.encryptors[sender_id].encrypt_frame(frame, sender_id, media_type)
    
    def decrypt_media_frame(self, encrypted_frame: bytes, sender_id: str) -> bytes:
        """Decripta un frame media"""
        if sender_id not in self.encryptors:
            raise ValueError(f"No encryptor for participant {sender_id}")
        
        return self.encryptors[sender_id].decrypt_frame(encrypted_frame, sender_id)
    
    def rotate_all_keys(self, new_signal_keys: Dict[str, bytes]):
        """
        Ruota tutte le chiavi (ad esempio quando cambia speaker o per sicurezza)
        
        Args:
            new_signal_keys: Dict participant_id -> nuova chiave Signal
        """
        logger.info(f"Rotating all keys for call {self.call_id}")
        
        for participant_id, new_key in new_signal_keys.items():
            if participant_id in self.participants:
                self.key_manager.rotate_key(participant_id, new_key)
                # Ricrea encryptor con nuova chiave
                self.encryptors[participant_id] = SFrameEncryptor(self.key_manager)
    
    def get_encryption_stats(self) -> Dict:
        """Ottiene statistiche sulla crittografia"""
        return {
            'call_id': self.call_id,
            'participants': len(self.participants),
            'active_keys': len(self.key_manager.encryption_keys),
            'total_key_rotations': self.key_manager.current_key_id
        }


# Singleton per gestire tutte le chiamate attive
class GlobalSFrameManager:
    """Gestisce tutte le chiamate SFrame attive"""
    
    def __init__(self):
        self.active_calls: Dict[str, SFrameCallManager] = {}
    
    def create_call(self, call_id: str) -> SFrameCallManager:
        """Crea una nuova chiamata crittata"""
        if call_id in self.active_calls:
            logger.warning(f"Call {call_id} already exists")
            return self.active_calls[call_id]
        
        call_manager = SFrameCallManager(call_id)
        self.active_calls[call_id] = call_manager
        
        logger.info(f"Created encrypted call {call_id}")
        return call_manager
    
    def get_call(self, call_id: str) -> Optional[SFrameCallManager]:
        """Ottiene il manager per una chiamata"""
        return self.active_calls.get(call_id)
    
    def end_call(self, call_id: str):
        """Termina una chiamata crittata"""
        if call_id in self.active_calls:
            del self.active_calls[call_id]
            logger.info(f"Ended encrypted call {call_id}")
    
    def get_all_calls_stats(self) -> List[Dict]:
        """Ottiene statistiche di tutte le chiamate"""
        return [call.get_encryption_stats() for call in self.active_calls.values()]


# Istanza globale
sframe_manager = GlobalSFrameManager()
