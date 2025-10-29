#!/usr/bin/env python3
"""
SecureVOX Notify - Servizio di notifiche push personalizzato con E2EE
Gestisce messaggi, notifiche, chiamate e videochiamate per iOS, Android e Web
Sostituisce completamente Firebase per le notifiche real-time
NOTA: Le notifiche sono CIFRATE end-to-end per proteggere i metadati
"""

import asyncio
import json
import time
import sqlite3
from datetime import datetime
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict
from enum import Enum
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

# Tipi di notifiche supportate
class NotificationType(str, Enum):
    MESSAGE = "message"
    CALL = "call"
    VIDEO_CALL = "video_call"
    GROUP_CALL = "group_call"
    GROUP_VIDEO_CALL = "group_video_call"
    SYSTEM = "system"
    FRIEND_REQUEST = "friend_request"
    CHAT_INVITE = "chat_invite"
    CHAT_DELETED = "chat_deleted"

# Stati delle chiamate
class CallStatus(str, Enum):
    INCOMING = "incoming"
    RINGING = "ringing"
    ANSWERED = "answered"
    REJECTED = "rejected"
    ENDED = "ended"
    MISSED = "missed"

# Modelli per le notifiche
@dataclass
class Device:
    device_token: str
    user_id: str
    platform: str
    app_version: str
    last_seen: float
    is_online: bool = True
    websocket: Optional[WebSocket] = None

@dataclass
class Notification:
    id: str
    recipient_id: str
    title: str
    body: str
    data: Dict
    sender_id: str
    timestamp: float
    notification_type: NotificationType
    delivered: bool = False
    call_status: Optional[CallStatus] = None
    call_duration: Optional[int] = None  # in secondi per le chiamate

class DeviceRegistration(BaseModel):
    device_token: str
    user_id: str
    platform: str
    app_version: str

class NotificationRequest(BaseModel):
    recipient_id: str
    title: str
    body: str
    data: Dict
    sender_id: str
    timestamp: str
    notification_type: NotificationType = NotificationType.MESSAGE
    # E2EE: Campi per notifiche cifrate
    encrypted: bool = False  # Se True, usa encrypted_payload invece di title/body
    encrypted_payload: Optional[Dict] = None  # {ciphertext, iv, mac}

class CallRequest(BaseModel):
    recipient_id: str
    sender_id: str
    call_type: str  # "audio" o "video"
    is_group: bool = False
    group_members: Optional[List[str]] = None
    call_id: str
    auth_token: Optional[str] = None

class GroupCallRequest(BaseModel):
    sender_id: str
    group_members: List[str]
    call_type: str  # "audio" o "video"
    room_name: Optional[str] = "Group Call"
    max_participants: Optional[int] = 10
    call_id: Optional[str] = None
    auth_token: Optional[str] = None

class CallResponse(BaseModel):
    call_id: str
    status: CallStatus
    message: str

class NotificationResponse(BaseModel):
    notifications: List[Dict]
    status: str

# Inizializza FastAPI
app = FastAPI(title="SecureVOX Notify", version="1.0.0")

# CORS per permettere richieste dal frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Storage in memoria (in produzione usare Redis o database)
devices: Dict[str, Device] = {}
notifications: Dict[str, List[Notification]] = {}
active_calls: Dict[str, Dict] = {}  # call_id -> call_data
notification_counter = 0
call_counter = 0

# Mappature per gestire user_id <-> device_token
user_to_device: Dict[str, str] = {}  # user_id -> device_token
device_to_user: Dict[str, str] = {}  # device_token -> user_id

# 💾 DATABASE PERSISTENTE PER DISPOSITIVI
DB_PATH = "securevox_notify_devices.db"

def init_database():
    """Inizializza il database SQLite per salvare i dispositivi"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Crea la tabella dei dispositivi se non esiste
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS devices (
            device_token TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            platform TEXT NOT NULL,
            app_version TEXT NOT NULL,
            last_seen REAL NOT NULL,
            is_online INTEGER NOT NULL DEFAULT 1
        )
    ''')
    
    # Crea indice su user_id per ricerche veloci
    cursor.execute('''
        CREATE INDEX IF NOT EXISTS idx_user_id ON devices(user_id)
    ''')
    
    conn.commit()
    conn.close()
    print("💾 Database dispositivi inizializzato")

def save_device_to_db(device: Device):
    """Salva un dispositivo nel database"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT OR REPLACE INTO devices (device_token, user_id, platform, app_version, last_seen, is_online)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (device.device_token, device.user_id, device.platform, device.app_version, 
              device.last_seen, 1 if device.is_online else 0))
        
        conn.commit()
        conn.close()
        print(f"💾 Dispositivo salvato nel DB: {device.user_id} ({device.device_token[:20]}...)")
    except Exception as e:
        print(f"❌ Errore salvataggio dispositivo: {e}")

def load_devices_from_db():
    """Carica tutti i dispositivi dal database"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('SELECT device_token, user_id, platform, app_version, last_seen, is_online FROM devices')
        rows = cursor.fetchall()
        
        conn.close()
        
        loaded_count = 0
        for row in rows:
            device_token, user_id, platform, app_version, last_seen, is_online = row
            
            device = Device(
                device_token=device_token,
                user_id=user_id,
                platform=platform,
                app_version=app_version,
                last_seen=last_seen,
                is_online=bool(is_online),
                websocket=None
            )
            
            devices[device_token] = device
            user_to_device[user_id] = device_token
            device_to_user[device_token] = user_id
            loaded_count += 1
        
        print(f"💾 Caricati {loaded_count} dispositivi dal database")
        return loaded_count
    except Exception as e:
        print(f"❌ Errore caricamento dispositivi: {e}")
        return 0

def remove_device_from_db(device_token: str):
    """Rimuove un dispositivo dal database"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('DELETE FROM devices WHERE device_token = ?', (device_token,))
        
        conn.commit()
        conn.close()
        print(f"💾 Dispositivo rimosso dal DB: {device_token[:20]}...")
    except Exception as e:
        print(f"❌ Errore rimozione dispositivo: {e}")

def initialize_mappings():
    """Inizializza le mappature all'avvio del server"""
    global user_to_device, device_to_user
    
    print("🔄 Inizializzazione mappature...")
    print(f"📋 Dispositivi registrati: {len(devices)}")
    
    # Ricarica le mappature dai dispositivi esistenti
    for device_token, device in devices.items():
        user_id = device.user_id
        user_to_device[user_id] = device_token
        device_to_user[device_token] = user_id
        print(f"✅ Mappatura: {user_id} -> {device_token[:20]}...")
    
    print(f"📋 Mappature inizializzate:")
    print(f"   - user_to_device: {len(user_to_device)} entries")
    print(f"   - device_to_user: {len(device_to_user)} entries")

def generate_notification_id() -> str:
    global notification_counter
    notification_counter += 1
    return f"notif_{int(time.time() * 1000)}_{notification_counter}"

def generate_call_id() -> str:
    global call_counter
    call_counter += 1
    return f"call_{int(time.time() * 1000)}_{call_counter}"

async def auto_timeout_call(call_id: str, timeout_seconds: int):
    """Timeout automatico per chiamate non risposte"""
    await asyncio.sleep(timeout_seconds)
    
    if call_id in active_calls:
        call_info = active_calls[call_id]
        if call_info["status"] == CallStatus.INCOMING:
            # Chiamata non risposta - imposta come MISSED
            call_info["status"] = CallStatus.MISSED
            call_info["end_time"] = time.time()
            call_info["duration"] = int(call_info["end_time"] - call_info["start_time"])
            
            # Notifica il chiamante
            caller_notification = {
                "type": "call_status",
                "call_id": call_id,
                "status": CallStatus.MISSED.value,
                "message": "Chiamata non risposta",
                "timestamp": time.time()
            }
            await send_websocket_notification(call_info["sender_id"], caller_notification)
            
            # Notifica il destinatario (chiamata persa)
            missed_notification = {
                "type": "call_missed",
                "call_id": call_id,
                "caller_id": call_info["sender_id"],
                "call_type": call_info["call_type"],
                "timestamp": time.time()
            }
            await send_websocket_notification(call_info["recipient_id"], missed_notification)
            
            print(f"📞 Chiamata {call_id} scaduta per timeout (non risposta)")

async def integrate_with_webrtc_server(call_id: str, action: str, user_data: dict = None):
    """Integra con il server WebRTC Django per gestire le sessioni"""
    try:
        import aiohttp
        webrtc_url = "http://localhost:8000/api/webrtc"
        
        async with aiohttp.ClientSession() as session:
            if action == "create_session":
                # Crea sessione WebRTC per chiamata 1:1
                async with session.post(
                    f"{webrtc_url}/calls/create/",
                    json={
                        "callee_id": user_data.get("recipient_id"),
                        "call_type": user_data.get("call_type", "video")
                    },
                    headers={"Authorization": f"Token {user_data.get('auth_token')}"}
                ) as response:
                    if response.status == 200:
                        session_data = await response.json()
                        return session_data
                        
            elif action == "create_group_session":
                # Crea sessione WebRTC per chiamata di gruppo
                async with session.post(
                    f"{webrtc_url}/calls/group/",
                    json={
                        "room_name": user_data.get("room_name", "Group Call"),
                        "max_participants": user_data.get("max_participants", 10),
                        "call_type": user_data.get("call_type", "video")
                    },
                    headers={"Authorization": f"Token {user_data.get('auth_token')}"}
                ) as response:
                    if response.status == 200:
                        session_data = await response.json()
                        return session_data
                    
            elif action == "end_session":
                # Termina sessione WebRTC
                async with session.post(
                    f"{webrtc_url}/calls/end/",
                    json={"session_id": call_id},
                    headers={"Authorization": f"Token {user_data.get('auth_token')}"}
                ) as response:
                    return response.status == 200
                    
    except Exception as e:
        print(f"❌ Errore integrazione WebRTC per {action}: {e}")
        return None

async def send_websocket_notification(user_id: str, notification_data: Dict):
    """Invia notifica tramite WebSocket se disponibile"""
    # Trova il device_token per questo user_id
    device_token = user_to_device.get(user_id)
    if device_token:
        device = devices.get(device_token)
        if device and device.websocket:
            try:
                await device.websocket.send_text(json.dumps(notification_data))
                print(f"📡 Notifica WebSocket inviata a {user_id}")
            except Exception as e:
                print(f"❌ Errore WebSocket per {user_id}: {e}")
                device.websocket = None

def cleanup_old_notifications():
    """Rimuove notifiche più vecchie di 1 ora"""
    current_time = time.time()
    for user_id in list(notifications.keys()):
        notifications[user_id] = [
            notif for notif in notifications[user_id]
            if current_time - notif.timestamp < 3600  # 1 ora
        ]
        if not notifications[user_id]:
            del notifications[user_id]

@app.post("/register")
async def register_device(device_data: DeviceRegistration):
    """Registra un nuovo dispositivo per le notifiche"""
    try:
        device = Device(
            device_token=device_data.device_token,
            user_id=device_data.user_id,
            platform=device_data.platform,
            app_version=device_data.app_version,
            last_seen=time.time(),
            is_online=True
        )
        
        devices[device_data.device_token] = device
        
        # Aggiorna le mappature user_id <-> device_token
        user_to_device[device_data.user_id] = device_data.device_token
        device_to_user[device_data.device_token] = device_data.user_id
        
        # 💾 SALVA NEL DATABASE PERSISTENTE
        save_device_to_db(device)
        
        print(f"🔥 Dispositivo registrato: {device_data.user_id} ({device_data.platform})")
        print(f"🔥 Token: {device_data.device_token[:20]}...")
        print(f"📋 Mappature aggiornate:")
        print(f"   - user_to_device: {len(user_to_device)} entries")
        print(f"   - device_to_user: {len(device_to_user)} entries")
        
        return {"status": "success", "message": "Dispositivo registrato"}
        
    except Exception as e:
        print(f"❌ Errore nella registrazione dispositivo: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/send")
async def send_notification(notification_data: NotificationRequest):
    """Invia una notifica a un destinatario"""
    try:
        # Trova il dispositivo del destinatario usando le mappature
        recipient_device = None
        recipient_user_id = None
        
        # Se recipient_id è un user_id, trova il device_token corrispondente
        print(f"🔍 Cercando recipient_id: {notification_data.recipient_id} (tipo: {type(notification_data.recipient_id)})")
        print(f"🔍 user_to_device keys: {list(user_to_device.keys())}")
        print(f"🔍 user_to_device values: {list(user_to_device.values())}")
        
        if notification_data.recipient_id in user_to_device:
            recipient_user_id = notification_data.recipient_id
            device_token = user_to_device[notification_data.recipient_id]
            recipient_device = devices.get(device_token)
            print(f"✅ Trovato dispositivo per user_id {recipient_user_id}: {device_token[:20]}...")
            print(f"📤 Notifica per user_id: {recipient_user_id} -> device_token: {device_token[:20]}...")
        
        # Se recipient_id è un device_token, trova il user_id corrispondente
        elif notification_data.recipient_id in device_to_user:
            device_token = notification_data.recipient_id
            recipient_user_id = device_to_user[notification_data.recipient_id]
            recipient_device = devices.get(device_token)
            print(f"📤 Notifica per device_token: {device_token[:20]}... -> user_id: {recipient_user_id}")
        
        # Fallback: cerca direttamente nei dispositivi
        else:
            print(f"⚠️ Recipient ID non trovato nelle mappature: {notification_data.recipient_id}")
            print(f"📋 User IDs disponibili: {list(user_to_device.keys())}")
            print(f"📋 Device tokens disponibili: {list(device_to_user.keys())}")
            print(f"📋 Dispositivi registrati: {len(devices)}")
            
            # Prova a cercare per user_id nei dispositivi
            for device_token, device in devices.items():
                print(f"🔍 Controllo dispositivo: {device_token[:20]}... -> user_id: {device.user_id}")
                if device.user_id == notification_data.recipient_id:
                    recipient_device = device
                    recipient_user_id = device.user_id
                    print(f"✅ Dispositivo trovato per user_id: {device.user_id}")
                    break
        
        if not recipient_device:
            print(f"❌ Dispositivo destinatario non trovato: {notification_data.recipient_id}")
            return {"status": "error", "message": "Destinatario non trovato"}
        
        # 🔐 E2EE: Gestione notifiche cifrate
        if notification_data.encrypted and notification_data.encrypted_payload:
            print(f"🔐 Notifica CIFRATA ricevuta per {notification_data.recipient_id}")
            # Notifica cifrata: usa placeholder generici
            title = "🔐 Nuovo messaggio"  # Placeholder generico
            body = "Hai ricevuto un nuovo messaggio"  # Placeholder generico
            
            # Includi payload cifrato nei dati
            notification_data_dict = {
                'encrypted': True,
                'encrypted_payload': notification_data.encrypted_payload,
                'sender_id': notification_data.sender_id,
                'notification_type': notification_data.notification_type.value,
                'timestamp': notification_data.timestamp
            }
            print(f"🔐 Payload cifrato: ciphertext={len(notification_data.encrypted_payload.get('ciphertext', ''))} bytes")
        
        # Gestione speciale per eliminazione chat
        elif notification_data.notification_type == NotificationType.CHAT_DELETED:
            # Per eliminazione chat, usa i dati dal payload
            title = f"Chat eliminata"
            body = f"La chat '{notification_data.data.get('chat_name', 'Chat')}' è stata eliminata"
            notification_data_dict = notification_data.data.copy()
            notification_data_dict.update({
                'type': 'chat_deleted',
                'chat_id': notification_data.data.get('chat_id'),
                'chat_name': notification_data.data.get('chat_name'),
                'deleted_by': notification_data.data.get('deleted_by'),
                'deleted_by_name': notification_data.data.get('deleted_by_name'),
                'timestamp': notification_data.data.get('timestamp')
            })
        else:
            # Notifica non cifrata (legacy)
            title = notification_data.title
            body = notification_data.body
            notification_data_dict = notification_data.data

        # Crea la notifica usando il recipient_user_id corretto
        notification = Notification(
            id=generate_notification_id(),
            recipient_id=recipient_user_id or notification_data.recipient_id,
            title=title,
            body=body,
            data=notification_data_dict,
            sender_id=notification_data.sender_id,
            timestamp=time.time(),
            notification_type=notification_data.notification_type,
            delivered=False
        )
        
        # Aggiungi la notifica alla coda del destinatario
        # CORREZIONE: Usa sempre recipient_user_id per salvare le notifiche
        if recipient_user_id not in notifications:
            notifications[recipient_user_id] = []
        
        notifications[recipient_user_id].append(notification)
        
        # Invia anche tramite WebSocket se disponibile
        notification_data_ws = {
            "type": "notification" if notification_data.notification_type != NotificationType.CHAT_DELETED else "chat_deleted",
            "id": notification.id,
            "title": notification.title,
            "body": notification.body,
            "data": notification.data,
            "timestamp": notification.timestamp,
            "notification_type": notification.notification_type.value
        }
        await send_websocket_notification(notification_data.recipient_id, notification_data_ws)
        
        print(f"📤 Notifica inviata a {notification_data.recipient_id}: {notification_data.title}")
        print(f"📤 Tipo: {notification_data.notification_type}")
        print(f"📤 Contenuto: {notification_data.body}")
        
        # Pulisci notifiche vecchie
        cleanup_old_notifications()
        
        return {"status": "success", "message": "Notifica inviata", "notification_id": notification.id}
        
    except Exception as e:
        print(f"❌ Errore nell'invio notifica: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/call/start")
async def start_call(call_data: CallRequest):
    """Inizia una chiamata audio o video"""
    try:
        call_id = call_data.call_id or generate_call_id()
        
        # Verifica che il destinatario sia online
        recipient_device = None
        for device in devices.values():
            if device.user_id == call_data.recipient_id:
                recipient_device = device
                break
        
        if not recipient_device:
            return CallResponse(
                call_id=call_id,
                status=CallStatus.REJECTED,
                message="Destinatario non trovato o offline"
            )
        
        # Crea la chiamata
        call_info = {
            "call_id": call_id,
            "sender_id": call_data.sender_id,
            "recipient_id": call_data.recipient_id,
            "call_type": call_data.call_type,
            "is_group": call_data.is_group,
            "group_members": call_data.group_members or [],
            "status": CallStatus.INCOMING,
            "start_time": time.time(),
            "end_time": None,
            "duration": None,
            "webrtc_session": None,  # Verrà impostato quando la chiamata viene accettata
            "ice_servers": None,     # Verrà impostato dal server WebRTC
            "janus_room_id": None    # ID della stanza Janus per WebRTC
        }
        
        active_calls[call_id] = call_info
        
        # Crea notifica di chiamata con informazioni WebRTC
        call_title = f"Chiamata {call_data.call_type}" if call_data.call_type == "audio" else f"Videochiamata"
        if call_data.is_group:
            call_title = f"Chiamata di gruppo {call_data.call_type}"
        
        notification = Notification(
            id=generate_notification_id(),
            recipient_id=call_data.recipient_id,
            title=call_title,
            body=f"Chiamata in arrivo da {call_data.sender_id}",
            data={
                "call_id": call_id,
                "call_type": call_data.call_type,
                "is_group": call_data.is_group,
                "group_members": call_data.group_members or [],
                "sender_id": call_data.sender_id,
                "timestamp": time.time(),
                "priority": "high"  # Alta priorità per le chiamate
            },
            sender_id=call_data.sender_id,
            timestamp=time.time(),
            notification_type=NotificationType.CALL if call_data.call_type == "audio" else NotificationType.VIDEO_CALL,
            call_status=CallStatus.INCOMING,
            delivered=False
        )
        
        # Aggiungi alla coda notifiche
        if call_data.recipient_id not in notifications:
            notifications[call_data.recipient_id] = []
        notifications[call_data.recipient_id].append(notification)
        
        # Invia tramite WebSocket con priorità alta
        call_notification = {
            "type": "call",
            "call_id": call_id,
            "call_type": call_data.call_type,
            "is_group": call_data.is_group,
            "sender_id": call_data.sender_id,
            "recipient_id": call_data.recipient_id,
            "status": CallStatus.INCOMING.value,
            "timestamp": time.time(),
            "priority": "high",
            "timeout": 30  # Timeout chiamata in secondi
        }
        await send_websocket_notification(call_data.recipient_id, call_notification)
        
        # Programma timeout automatico per chiamata non risposta
        asyncio.create_task(auto_timeout_call(call_id, 30))
        
        print(f"📞 Chiamata {call_data.call_type} iniziata: {call_id}")
        print(f"📞 Da: {call_data.sender_id} a: {call_data.recipient_id}")
        
        return CallResponse(
            call_id=call_id,
            status=CallStatus.INCOMING,
            message="Chiamata inviata"
        )
        
    except Exception as e:
        print(f"❌ Errore nell'inizio chiamata: {e}")
        raise HTTPException(status_code=500, detail=str(e))

class CallAnswerRequest(BaseModel):
    user_id: str
    auth_token: Optional[str] = None

@app.post("/call/answer/{call_id}")
async def answer_call(call_id: str, request_data: CallAnswerRequest):
    """Risponde a una chiamata e crea sessione WebRTC"""
    try:
        if call_id not in active_calls:
            return CallResponse(
                call_id=call_id,
                status=CallStatus.REJECTED,
                message="Chiamata non trovata"
            )
        
        call_info = active_calls[call_id]
        
        # Verifica che l'utente sia autorizzato a rispondere
        if call_info["recipient_id"] != request_data.user_id:
            return CallResponse(
                call_id=call_id,
                status=CallStatus.REJECTED,
                message="Non autorizzato a rispondere a questa chiamata"
            )
        
        call_info["status"] = CallStatus.ANSWERED
        call_info["answer_time"] = time.time()
        
        # Integra con server WebRTC per creare sessione
        webrtc_session = await integrate_with_webrtc_server(
            call_id, 
            "create_session", 
            {
                "recipient_id": call_info["recipient_id"],
                "call_type": call_info["call_type"],
                "auth_token": request_data.auth_token
            }
        )
        
        if webrtc_session:
            call_info["webrtc_session"] = webrtc_session
            call_info["janus_room_id"] = webrtc_session.get("room_id")
            call_info["ice_servers"] = webrtc_session.get("ice_servers")
        
        # Notifica il chiamante con informazioni WebRTC
        caller_notification = {
            "type": "call_status",
            "call_id": call_id,
            "status": CallStatus.ANSWERED.value,
            "webrtc_session": webrtc_session,
            "timestamp": time.time()
        }
        await send_websocket_notification(call_info["sender_id"], caller_notification)
        
        # Notifica anche il destinatario (per conferma)
        recipient_notification = {
            "type": "call_answered",
            "call_id": call_id,
            "webrtc_session": webrtc_session,
            "timestamp": time.time()
        }
        await send_websocket_notification(call_info["recipient_id"], recipient_notification)
        
        print(f"📞 Chiamata {call_id} risposta da {request_data.user_id}")
        if webrtc_session:
            print(f"📞 Sessione WebRTC creata: {webrtc_session.get('session_id')}")
        
        return CallResponse(
            call_id=call_id,
            status=CallStatus.ANSWERED,
            message="Chiamata risposta e sessione WebRTC creata"
        )
        
    except Exception as e:
        print(f"❌ Errore nella risposta chiamata: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/call/reject/{call_id}")
async def reject_call(call_id: str, user_id: str):
    """Rifiuta una chiamata"""
    try:
        if call_id not in active_calls:
            return CallResponse(
                call_id=call_id,
                status=CallStatus.REJECTED,
                message="Chiamata non trovata"
            )
        
        call_info = active_calls[call_id]
        call_info["status"] = CallStatus.REJECTED
        call_info["end_time"] = time.time()
        call_info["duration"] = int(call_info["end_time"] - call_info["start_time"])
        
        # Notifica il chiamante
        caller_notification = {
            "type": "call_status",
            "call_id": call_id,
            "status": CallStatus.REJECTED.value,
            "timestamp": time.time()
        }
        await send_websocket_notification(call_info["sender_id"], caller_notification)
        
        print(f"📞 Chiamata {call_id} rifiutata da {user_id}")
        
        return CallResponse(
            call_id=call_id,
            status=CallStatus.REJECTED,
            message="Chiamata rifiutata"
        )
        
    except Exception as e:
        print(f"❌ Errore nel rifiuto chiamata: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/call/end/{call_id}")
async def end_call(call_id: str, user_id: str):
    """Termina una chiamata"""
    try:
        if call_id not in active_calls:
            return CallResponse(
                call_id=call_id,
                status=CallStatus.ENDED,
                message="Chiamata non trovata"
            )
        
        call_info = active_calls[call_id]
        call_info["status"] = CallStatus.ENDED
        call_info["end_time"] = time.time()
        call_info["duration"] = int(call_info["end_time"] - call_info["start_time"])
        
        # Notifica tutti i partecipanti
        participants = [call_info["sender_id"], call_info["recipient_id"]]
        if call_info.get("group_members"):
            participants.extend(call_info["group_members"])
        
        for participant in participants:
            if participant != user_id:  # Non notificare chi ha terminato
                end_notification = {
                    "type": "call_status",
                    "call_id": call_id,
                    "status": CallStatus.ENDED.value,
                    "duration": call_info["duration"],
                    "timestamp": time.time()
                }
                await send_websocket_notification(participant, end_notification)
        
        print(f"📞 Chiamata {call_id} terminata da {user_id} (durata: {call_info['duration']}s)")
        
        return CallResponse(
            call_id=call_id,
            status=CallStatus.ENDED,
            message="Chiamata terminata"
        )
        
    except Exception as e:
        print(f"❌ Errore nella terminazione chiamata: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/poll/{device_token}")
async def poll_notifications(device_token: str):
    """Polling per ottenere notifiche per un dispositivo"""
    try:
        print(f"🔄 Polling richiesto per device_token: {device_token[:20]}...")
        print(f"📋 Dispositivi registrati: {len(devices)}")
        
        # Trova il dispositivo
        device = devices.get(device_token)
        if not device:
            print(f"❌ Dispositivo non trovato: {device_token[:20]}...")
            print(f"📋 Device tokens disponibili: {list(devices.keys())[:5]}...")
            return {"notifications": [], "status": "device_not_found"}
        
        print(f"✅ Dispositivo trovato: {device.user_id} ({device.platform})")
        
        # Aggiorna last_seen
        device.last_seen = time.time()
        device.is_online = True
        
        # 💾 Aggiorna anche nel database
        save_device_to_db(device)
        
        # Ottieni le notifiche per questo utente
        user_notifications = notifications.get(device.user_id, [])
        print(f"🔍 Polling - User ID: {device.user_id}")
        print(f"🔍 Polling - Notifiche totali per utente: {len(user_notifications)}")
        print(f"🔍 Polling - Notifiche disponibili: {list(notifications.keys())}")
        
        # Filtra solo notifiche non consegnate
        pending_notifications = [
            notif for notif in user_notifications 
            if not notif.delivered
        ]
        print(f"🔍 Polling - Notifiche non consegnate: {len(pending_notifications)}")
        
        # Marca come consegnate
        for notif in pending_notifications:
            notif.delivered = True
        
        # Converti in formato JSON
        notifications_data = []
        for notif in pending_notifications:
            notifications_data.append({
                "id": notif.id,
                "title": notif.title,
                "body": notif.body,
                "data": notif.data,
                "timestamp": notif.timestamp,
                "sender_id": notif.sender_id
            })
        
        if notifications_data:
            print(f"📨 Inviate {len(notifications_data)} notifiche a {device.user_id}")
        
        return {
            "notifications": notifications_data,
            "status": "success",
            "count": len(notifications_data)
        }
        
    except Exception as e:
        print(f"❌ Errore nel polling: {e}")
        return {"notifications": [], "status": "error"}

@app.get("/devices")
async def list_devices():
    """Lista tutti i dispositivi registrati (per debug)"""
    device_list = []
    for device in devices.values():
        device_dict = {
            "device_token": device.device_token,
            "user_id": device.user_id,
            "platform": device.platform,
            "app_version": device.app_version,
            "last_seen": device.last_seen,
            "is_online": device.is_online,
            "has_websocket": device.websocket is not None,
        }
        device_list.append(device_dict)
    
    return {
        "devices": device_list,
        "count": len(devices)
    }

@app.post("/initialize")
async def initialize_server():
    """Inizializza le mappature del server"""
    try:
        initialize_mappings()
        return {
            "status": "success",
            "message": "Mappature inizializzate",
            "user_to_device_count": len(user_to_device),
            "device_to_user_count": len(device_to_user)
        }
    except Exception as e:
        print(f"❌ Errore inizializzazione: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/notifications/{user_id}")
async def get_user_notifications(user_id: str):
    """Ottieni tutte le notifiche per un utente (per debug)"""
    user_notifications = notifications.get(user_id, [])
    return {
        "notifications": [asdict(notif) for notif in user_notifications],
        "count": len(user_notifications)
    }

@app.delete("/notifications/{user_id}")
async def clear_user_notifications(user_id: str):
    """Cancella tutte le notifiche per un utente"""
    if user_id in notifications:
        del notifications[user_id]
        return {"status": "success", "message": f"Notifiche cancellate per {user_id}"}
    return {"status": "error", "message": "Utente non trovato"}

@app.get("/health")
async def health_check():
    """Health check del servizio"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "devices_count": len(devices),
        "notifications_count": sum(len(notifs) for notifs in notifications.values())
    }

@app.websocket("/ws/{device_token}")
async def websocket_endpoint(websocket: WebSocket, device_token: str):
    """WebSocket per notifiche real-time"""
    await websocket.accept()
    
    # Trova il dispositivo
    device = devices.get(device_token)
    if not device:
        await websocket.close(code=1008, reason="Device not found")
        return
    
    # Aggiorna il WebSocket del dispositivo
    device.websocket = websocket
    device.is_online = True
    device.last_seen = time.time()
    
    print(f"📡 WebSocket connesso per {device.user_id} ({device.platform})")
    
    try:
        while True:
            # Mantieni la connessione attiva
            data = await websocket.receive_text()
            message = json.loads(data)
            
            # Gestisci messaggi dal client
            if message.get("type") == "ping":
                await websocket.send_text(json.dumps({"type": "pong", "timestamp": time.time()}))
            elif message.get("type") == "call_response":
                # Gestisci risposta chiamata
                call_id = message.get("call_id")
                action = message.get("action")  # "answer", "reject", "end"
                user_id = device.user_id
                
                if action == "answer":
                    await answer_call(call_id, user_id)
                elif action == "reject":
                    await reject_call(call_id, user_id)
                elif action == "end":
                    await end_call(call_id, user_id)
                    
    except WebSocketDisconnect:
        print(f"📡 WebSocket disconnesso per {device.user_id}")
        device.websocket = None
        device.is_online = False
    except Exception as e:
        print(f"❌ Errore WebSocket per {device.user_id}: {e}")
        device.websocket = None
        device.is_online = False

@app.get("/calls/active")
async def get_active_calls():
    """Ottieni tutte le chiamate attive"""
    return {
        "active_calls": list(active_calls.values()),
        "count": len(active_calls)
    }

@app.get("/calls/{call_id}")
async def get_call_info(call_id: str):
    """Ottieni informazioni su una chiamata specifica"""
    if call_id not in active_calls:
        raise HTTPException(status_code=404, detail="Chiamata non trovata")
    
    return {
        "call": active_calls[call_id],
        "status": "found"
    }

@app.post("/call/group/start")
async def start_group_call(call_data: GroupCallRequest):
    """Inizia una chiamata di gruppo"""
    try:
        call_id = call_data.call_id or generate_call_id()
        
        # Verifica che tutti i membri siano online
        online_members = []
        offline_members = []
        
        for member_id in call_data.group_members:
            device_found = False
            for device in devices.values():
                if device.user_id == member_id and device.is_online:
                    online_members.append(member_id)
                    device_found = True
                    break
            if not device_found:
                offline_members.append(member_id)
        
        if not online_members:
            return CallResponse(
                call_id=call_id,
                status=CallStatus.REJECTED,
                message="Nessun membro del gruppo è online"
            )
        
        # Crea chiamata di gruppo
        call_info = {
            "call_id": call_id,
            "sender_id": call_data.sender_id,
            "call_type": call_data.call_type,
            "is_group": True,
            "group_members": call_data.group_members,
            "online_members": online_members,
            "offline_members": offline_members,
            "room_name": call_data.room_name,
            "max_participants": call_data.max_participants,
            "status": CallStatus.INCOMING,
            "start_time": time.time(),
            "end_time": None,
            "duration": None,
            "webrtc_session": None,
            "janus_room_id": None,
            "participants_joined": []
        }
        
        active_calls[call_id] = call_info
        
        # Invia notifiche a tutti i membri online
        for member_id in online_members:
            if member_id != call_data.sender_id:  # Non notificare il creatore
                notification = Notification(
                    id=generate_notification_id(),
                    recipient_id=member_id,
                    title=f"Chiamata di gruppo {call_data.call_type}",
                    body=f"{call_data.room_name} - Invitato da {call_data.sender_id}",
                    data={
                        "call_id": call_id,
                        "call_type": call_data.call_type,
                        "is_group": True,
                        "group_members": call_data.group_members,
                        "room_name": call_data.room_name,
                        "sender_id": call_data.sender_id,
                        "timestamp": time.time(),
                        "priority": "high"
                    },
                    sender_id=call_data.sender_id,
                    timestamp=time.time(),
                    notification_type=NotificationType.GROUP_CALL if call_data.call_type == "audio" else NotificationType.GROUP_VIDEO_CALL,
                    call_status=CallStatus.INCOMING,
                    delivered=False
                )
                
                # Aggiungi alla coda notifiche
                if member_id not in notifications:
                    notifications[member_id] = []
                notifications[member_id].append(notification)
                
                # Invia tramite WebSocket
                call_notification = {
                    "type": "group_call",
                    "call_id": call_id,
                    "call_type": call_data.call_type,
                    "room_name": call_data.room_name,
                    "sender_id": call_data.sender_id,
                    "group_members": call_data.group_members,
                    "online_members": online_members,
                    "status": CallStatus.INCOMING.value,
                    "timestamp": time.time(),
                    "priority": "high",
                    "timeout": 60  # Timeout più lungo per chiamate di gruppo
                }
                await send_websocket_notification(member_id, call_notification)
        
        # Programma timeout automatico
        asyncio.create_task(auto_timeout_call(call_id, 60))
        
        print(f"📞 Chiamata di gruppo {call_data.call_type} iniziata: {call_id}")
        print(f"📞 Creatore: {call_data.sender_id}, Membri online: {len(online_members)}")
        if offline_members:
            print(f"📞 Membri offline: {offline_members}")
        
        return CallResponse(
            call_id=call_id,
            status=CallStatus.INCOMING,
            message=f"Chiamata di gruppo inviata a {len(online_members)} membri"
        )
        
    except Exception as e:
        print(f"❌ Errore nell'inizio chiamata di gruppo: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/call/group/join/{call_id}")
async def join_group_call(call_id: str, request_data: CallAnswerRequest):
    """Partecipa a una chiamata di gruppo"""
    try:
        if call_id not in active_calls:
            return CallResponse(
                call_id=call_id,
                status=CallStatus.REJECTED,
                message="Chiamata di gruppo non trovata"
            )
        
        call_info = active_calls[call_id]
        
        # Verifica che l'utente sia nei membri del gruppo
        if request_data.user_id not in call_info["group_members"]:
            return CallResponse(
                call_id=call_id,
                status=CallStatus.REJECTED,
                message="Non autorizzato a partecipare a questa chiamata"
            )
        
        # Aggiungi ai partecipanti
        if request_data.user_id not in call_info["participants_joined"]:
            call_info["participants_joined"].append(request_data.user_id)
        
        # Se è il primo a partecipare, crea la sessione WebRTC
        if not call_info["webrtc_session"] and len(call_info["participants_joined"]) == 1:
            # Integra con server WebRTC per creare stanza di gruppo
            webrtc_session = await integrate_with_webrtc_server(
                call_id, 
                "create_group_session", 
                {
                    "room_name": call_info["room_name"],
                    "max_participants": call_info["max_participants"],
                    "call_type": call_info["call_type"],
                    "auth_token": request_data.auth_token
                }
            )
            
            if webrtc_session:
                call_info["webrtc_session"] = webrtc_session
                call_info["janus_room_id"] = webrtc_session.get("room_id")
                call_info["status"] = CallStatus.ANSWERED
        
        # Notifica tutti i partecipanti del nuovo membro
        for member_id in call_info["participants_joined"]:
            member_notification = {
                "type": "group_call_member_joined",
                "call_id": call_id,
                "joined_member": request_data.user_id,
                "participants_count": len(call_info["participants_joined"]),
                "webrtc_session": call_info["webrtc_session"],
                "timestamp": time.time()
            }
            await send_websocket_notification(member_id, member_notification)
        
        print(f"📞 {request_data.user_id} si è unito alla chiamata di gruppo {call_id}")
        print(f"📞 Partecipanti totali: {len(call_info['participants_joined'])}")
        
        return CallResponse(
            call_id=call_id,
            status=CallStatus.ANSWERED,
            message="Partecipazione alla chiamata di gruppo confermata"
        )
        
    except Exception as e:
        print(f"❌ Errore nella partecipazione chiamata di gruppo: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/calls/{call_id}")
async def cleanup_call(call_id: str):
    """Pulisci una chiamata terminata"""
    if call_id in active_calls:
        del active_calls[call_id]
        return {"status": "success", "message": f"Chiamata {call_id} pulita"}
    return {"status": "error", "message": "Chiamata non trovata"}

@app.get("/stats")
async def get_stats():
    """Statistiche del servizio"""
    online_devices = sum(1 for device in devices.values() if device.is_online)
    total_notifications = sum(len(notifs) for notifs in notifications.values())
    
    return {
        "devices": {
            "total": len(devices),
            "online": online_devices,
            "offline": len(devices) - online_devices
        },
        "notifications": {
            "total": total_notifications,
            "by_user": {user_id: len(notifs) for user_id, notifs in notifications.items()}
        },
        "calls": {
            "active": len(active_calls),
            "total_today": call_counter
        },
        "platforms": {
            platform: sum(1 for device in devices.values() if device.platform == platform)
            for platform in set(device.platform for device in devices.values())
        }
    }

@app.get("/")
async def root():
    """Endpoint root"""
    return {
        "service": "SecureVOX Notify",
        "version": "1.0.0",
        "status": "running",
        "platforms": ["iOS", "Android", "Web"],
        "features": [
            "Messaggi real-time",
            "Chiamate audio/video",
            "Chiamate di gruppo",
            "Notifiche push",
            "WebSocket real-time"
        ],
        "endpoints": [
            "POST /register - Registra dispositivo",
            "POST /send - Invia notifica",
            "GET /poll/{device_token} - Polling notifiche",
            "WS /ws/{device_token} - WebSocket real-time",
            "POST /call/start - Inizia chiamata 1:1",
            "POST /call/group/start - Inizia chiamata di gruppo",
            "POST /call/answer/{call_id} - Rispondi chiamata",
            "POST /call/group/join/{call_id} - Partecipa a chiamata di gruppo",
            "POST /call/reject/{call_id} - Rifiuta chiamata",
            "POST /call/end/{call_id} - Termina chiamata",
            "GET /devices - Lista dispositivi",
            "GET /calls/active - Chiamate attive",
            "GET /calls/{call_id} - Info chiamata specifica",
            "DELETE /calls/{call_id} - Pulisci chiamata",
            "GET /stats - Statistiche servizio",
            "GET /health - Health check"
        ]
    }

if __name__ == "__main__":
    print("🚀 Avvio SecureVOX Notify...")
    print("🔥 Server in ascolto su http://localhost:8002")
    print("📡 WebSocket disponibile su ws://localhost:8002/ws/{device_token}")
    print("📱 Supporta iOS, Android e Web")
    print("")
    
    # 💾 Inizializza il database e carica dispositivi salvati
    print("💾 Inizializzazione database...")
    init_database()
    loaded_count = load_devices_from_db()
    print(f"✅ Database pronto! {loaded_count} dispositivi caricati")
    print("")
    
    # Inizializza le mappature all'avvio
    initialize_mappings()
    
    uvicorn.run(
        "securevox_notify:app",
        host="0.0.0.0",
        port=8002,
        reload=True,
        log_level="info"
    )
