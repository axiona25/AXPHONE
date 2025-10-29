import json
import asyncio
import logging
from datetime import datetime
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import User
from django.utils import timezone
from crypto.models import Device, Message, Session
from admin_panel.models import UserProfile, AdminAction

logger = logging.getLogger('securevox')

class AdminDashboardConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.room_name = 'admin_dashboard'
        self.room_group_name = f'dashboard_{self.room_name}'
        
        # Verifica autenticazione
        if self.scope['user'].is_authenticated and (
            self.scope['user'].is_staff or self.scope['user'].is_superuser
        ):
            # Accetta la connessione
            await self.channel_layer.group_add(
                self.room_group_name,
                self.channel_name
            )
            await self.accept()
            
            # Invia dati iniziali
            await self.send_initial_data()
            
            # Avvia il loop di aggiornamento
            asyncio.create_task(self.periodic_updates())
            
            logger.info(f"Admin dashboard WebSocket connected: {self.scope['user'].username}")
        else:
            await self.close()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )
        logger.info(f"Admin dashboard WebSocket disconnected: {self.scope['user'].username}")

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
            message_type = data.get('type')
            
            if message_type == 'request_dashboard_stats':
                await self.send_dashboard_stats()
            elif message_type == 'request_system_health':
                await self.send_system_health()
            elif message_type == 'request_server_status':
                await self.send_server_status()
            elif message_type == 'subscribe_user':
                await self.subscribe_to_user(data.get('user_id'))
            elif message_type == 'subscribe_server':
                await self.subscribe_to_server(data.get('server_id'))
            elif message_type == 'server_action':
                await self.handle_server_action(data.get('server_id'), data.get('action'))
            elif message_type == 'user_action':
                await self.handle_user_action(data.get('user_id'), data.get('action'))
            elif message_type == 'terminal_command':
                await self.handle_terminal_command(data.get('server_id'), data.get('command'))
                
        except json.JSONDecodeError:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'message': 'Invalid JSON'
            }))
        except Exception as e:
            logger.error(f"Error in WebSocket receive: {e}")
            await self.send(text_data=json.dumps({
                'type': 'error',
                'message': str(e)
            }))

    async def send_initial_data(self):
        """Invia i dati iniziali al client"""
        dashboard_stats = await self.get_dashboard_stats()
        system_health = await self.get_system_health()
        
        await self.send(text_data=json.dumps({
            'type': 'initial_data',
            'dashboard_stats': dashboard_stats,
            'system_health': system_health,
            'timestamp': timezone.now().isoformat()
        }))

    async def periodic_updates(self):
        """Loop periodico per aggiornamenti automatici"""
        while True:
            try:
                # Aggiorna dashboard stats ogni 10 secondi
                dashboard_stats = await self.get_dashboard_stats()
                await self.channel_layer.group_send(
                    self.room_group_name,
                    {
                        'type': 'dashboard_stats_update',
                        'data': dashboard_stats,
                        'timestamp': timezone.now().isoformat()
                    }
                )
                
                # Aggiorna system health ogni 5 secondi
                await asyncio.sleep(5)
                system_health = await self.get_system_health()
                await self.channel_layer.group_send(
                    self.room_group_name,
                    {
                        'type': 'system_health_update',
                        'data': system_health,
                        'timestamp': timezone.now().isoformat()
                    }
                )
                
                # Aggiorna server status ogni 15 secondi
                await asyncio.sleep(10)
                server_status = await self.get_server_status()
                await self.channel_layer.group_send(
                    self.room_group_name,
                    {
                        'type': 'server_status_update',
                        'servers': server_status,
                        'timestamp': timezone.now().isoformat()
                    }
                )
                
                # Attendi prima del prossimo ciclo
                await asyncio.sleep(10)
                
            except Exception as e:
                logger.error(f"Error in periodic updates: {e}")
                await asyncio.sleep(30)  # Attendi più a lungo in caso di errore

    async def send_dashboard_stats(self):
        """Invia le statistiche della dashboard"""
        stats = await self.get_dashboard_stats()
        await self.send(text_data=json.dumps({
            'type': 'dashboard_stats',
            'data': stats,
            'timestamp': timezone.now().isoformat()
        }))

    async def send_system_health(self):
        """Invia lo stato di salute del sistema"""
        health = await self.get_system_health()
        await self.send(text_data=json.dumps({
            'type': 'system_health',
            'data': health,
            'timestamp': timezone.now().isoformat()
        }))

    async def send_server_status(self):
        """Invia lo stato dei server"""
        servers = await self.get_server_status()
        await self.send(text_data=json.dumps({
            'type': 'server_status',
            'servers': servers,
            'timestamp': timezone.now().isoformat()
        }))

    # Handler per messaggi di gruppo
    async def dashboard_stats_update(self, event):
        """Invia aggiornamento statistiche dashboard"""
        await self.send(text_data=json.dumps({
            'type': 'dashboard_stats_update',
            'data': event['data'],
            'timestamp': event['timestamp']
        }))

    async def system_health_update(self, event):
        """Invia aggiornamento system health"""
        await self.send(text_data=json.dumps({
            'type': 'system_health_update',
            'data': event['data'],
            'timestamp': event['timestamp']
        }))

    async def server_status_update(self, event):
        """Invia aggiornamento stato server"""
        await self.send(text_data=json.dumps({
            'type': 'server_status_update',
            'servers': event['servers'],
            'timestamp': event['timestamp']
        }))

    async def user_activity(self, event):
        """Invia notifica attività utente"""
        await self.send(text_data=json.dumps({
            'type': 'user_activity',
            'user': event['user'],
            'activity': event['activity'],
            'timestamp': event['timestamp']
        }))

    async def security_alert(self, event):
        """Invia allerta sicurezza"""
        await self.send(text_data=json.dumps({
            'type': 'security_alert',
            'type': event['alert_type'],
            'message': event['message'],
            'severity': event['severity'],
            'timestamp': event['timestamp']
        }))

    async def new_message(self, event):
        """Invia notifica nuovo messaggio"""
        await self.send(text_data=json.dumps({
            'type': 'new_message',
            'count': event['count'],
            'timestamp': event['timestamp']
        }))

    async def new_call(self, event):
        """Invia notifica nuova chiamata"""
        await self.send(text_data=json.dumps({
            'type': 'new_call',
            'count': event['count'],
            'duration': event['duration'],
            'timestamp': event['timestamp']
        }))

    # Metodi per ottenere i dati
    @database_sync_to_async
    def get_dashboard_stats(self):
        """Ottiene le statistiche della dashboard"""
        now = timezone.now()
        last_24h = now - timezone.timedelta(hours=24)
        last_7d = now - timezone.timedelta(days=7)
        
        return {
            'users': {
                'total': User.objects.count(),
                'active_24h': User.objects.filter(last_login__gte=last_24h).count(),
                'online': User.objects.filter(last_login__gte=now - timezone.timedelta(minutes=5)).count(),
                'blocked': User.objects.filter(is_active=False).count(),
                'growth_rate': self.calculate_user_growth_rate(),
            },
            'devices': {
                'total': Device.objects.count(),
                'active': Device.objects.filter(is_active=True).count(),
                'compromised': Device.objects.filter(
                    is_rooted=True, is_jailbroken=True, is_compromised=True
                ).count(),
                'by_type': {
                    'android': Device.objects.filter(device_type='android', is_active=True).count(),
                    'ios': Device.objects.filter(device_type='ios', is_active=True).count(),
                    'web': Device.objects.filter(device_type='web', is_active=True).count(),
                    'desktop': Device.objects.filter(device_type='desktop', is_active=True).count(),
                }
            },
            'messages': {
                'total': Message.objects.count(),
                'last_24h': Message.objects.filter(created_at__gte=last_24h).count(),
                'last_7d': Message.objects.filter(created_at__gte=last_7d).count(),
                'by_type': {
                    'text': Message.objects.filter(message_type='text').count(),
                    'image': Message.objects.filter(message_type='image').count(),
                    'video': Message.objects.filter(message_type='video').count(),
                    'audio': Message.objects.filter(message_type='audio').count(),
                    'file': Message.objects.filter(message_type='file').count(),
                }
            },
            'calls': {
                'total': 0,  # Implementare quando disponibile
                'last_24h': 0,
                'average_duration': 180,
            },
            'chats': {
                'total': Session.objects.count(),
                'active': Session.objects.filter(last_message_at__gte=last_7d).count(),
            },
            'traffic': {
                'total_mb': Message.objects.count() * 0.1,  # Stima
                'daily_average_mb': Message.objects.filter(created_at__gte=last_24h).count() * 0.1,
                'trend': 'increasing',
            },
            'security': {
                'failed_logins_24h': 5,  # Mock
                'blocked_ips': 2,  # Mock
                'suspicious_activity': 1,  # Mock
            }
        }

    @database_sync_to_async
    def get_system_health(self):
        """Ottiene lo stato di salute del sistema"""
        try:
            import psutil
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
        except ImportError:
            cpu_percent = 45.0
            memory = type('obj', (object,), {'percent': 60.0, 'total': 8*1024**3, 'available': 3*1024**3})
            disk = type('obj', (object,), {'percent': 70.0, 'total': 500*1024**3, 'free': 150*1024**3})
        
        # Verifica servizi
        services_status = {
            'django': True,
            'call_server': self.check_service_health('http://localhost:8003/health'),
            'notification_server': self.check_service_health('http://localhost:8002/health'),
            'database': True,  # Se arriviamo qui, il DB funziona
            'redis': True,  # Mock
        }
        
        active_services = sum(1 for status in services_status.values() if status)
        health_score = (active_services / len(services_status)) * 100
        
        return {
            'system': {
                'cpu_usage': cpu_percent,
                'memory_usage': memory.percent,
                'memory_total': memory.total // (1024**3),
                'memory_available': memory.available // (1024**3),
                'disk_usage': disk.percent,
                'disk_total': disk.total // (1024**3),
                'disk_free': disk.free // (1024**3),
                'uptime': self.get_system_uptime(),
            },
            'services': services_status,
            'health_score': health_score,
            'status': 'healthy' if health_score > 80 else 'warning' if health_score > 50 else 'critical'
        }

    @database_sync_to_async
    def get_server_status(self):
        """Ottiene lo stato dei server"""
        # Mock per ora - implementare con i server reali
        return [
            {
                'id': 'django-server',
                'name': 'Django Server',
                'hostname': 'localhost',
                'ip_address': '127.0.0.1',
                'port': 8001,
                'technology': 'Django',
                'function': 'Web API',
                'status': 'active',
                'cpu_usage': 25.0,
                'memory_usage': 45.0,
                'disk_usage': 30.0,
                'uptime': 3600,
                'last_checked': timezone.now().isoformat(),
                'alerts': [],
                'size': '2GB',
            },
            {
                'id': 'call-server',
                'name': 'Call Server',
                'hostname': 'localhost',
                'ip_address': '127.0.0.1',
                'port': 8003,
                'technology': 'Node.js',
                'function': 'WebRTC Calls',
                'status': 'active',
                'cpu_usage': 15.0,
                'memory_usage': 30.0,
                'disk_usage': 20.0,
                'uptime': 3600,
                'last_checked': timezone.now().isoformat(),
                'alerts': [],
                'size': '1GB',
            },
            {
                'id': 'notification-server',
                'name': 'Notification Server',
                'hostname': 'localhost',
                'ip_address': '127.0.0.1',
                'port': 8002,
                'technology': 'Python',
                'function': 'Push Notifications',
                'status': 'active',
                'cpu_usage': 10.0,
                'memory_usage': 25.0,
                'disk_usage': 15.0,
                'uptime': 3600,
                'last_checked': timezone.now().isoformat(),
                'alerts': [],
                'size': '512MB',
            }
        ]

    def calculate_user_growth_rate(self):
        """Calcola il tasso di crescita utenti"""
        now = timezone.now()
        last_month = now - timezone.timedelta(days=30)
        
        current_users = User.objects.filter(date_joined__gte=last_month).count()
        previous_month = User.objects.filter(
            date_joined__gte=last_month - timezone.timedelta(days=30),
            date_joined__lt=last_month
        ).count()
        
        if previous_month == 0:
            return 100.0
        
        return ((current_users - previous_month) / previous_month) * 100

    def check_service_health(self, url):
        """Verifica lo stato di salute di un servizio"""
        try:
            import requests
            response = requests.get(url, timeout=5)
            return response.status_code == 200
        except:
            return False

    def get_system_uptime(self):
        """Ottiene l'uptime del sistema"""
        try:
            with open('/proc/uptime', 'r') as f:
                uptime_seconds = float(f.readline().split()[0])
            return int(uptime_seconds)
        except:
            return 0

    async def subscribe_to_user(self, user_id):
        """Sottoscrive agli aggiornamenti di un utente"""
        # Implementare sottoscrizione utente
        pass

    async def subscribe_to_server(self, server_id):
        """Sottoscrive agli aggiornamenti di un server"""
        # Implementare sottoscrizione server
        pass

    async def handle_server_action(self, server_id, action):
        """Gestisce azioni sui server"""
        # Implementare azioni server
        pass

    async def handle_user_action(self, user_id, action):
        """Gestisce azioni sugli utenti"""
        # Implementare azioni utenti
        pass

    async def handle_terminal_command(self, server_id, command):
        """Gestisce comandi terminale"""
        # Implementare comandi terminale
        pass
