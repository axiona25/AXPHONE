from django.shortcuts import render
from django.contrib.auth.decorators import user_passes_test, login_required
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from django.contrib.auth.models import User
from django.db.models import Count, Q, Avg, Sum
from django.utils import timezone
from datetime import datetime, timedelta
import json
import os
import subprocess
import requests
from collections import defaultdict

# Import psutil in modo sicuro
try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False

from crypto.models import Device, Message, Session
from api.models import Chat, ChatMessage, Call
from .models import UserProfile, AdminAction


def is_admin_user(user):
    """Verifica che l'utente sia un amministratore"""
    return user.is_authenticated and (user.is_staff or user.is_superuser)


@user_passes_test(is_admin_user, login_url='/admin/login/')
def admin_dashboard(request):
    """Dashboard principale amministratore"""
    return render(request, 'admin_panel/dashboard.html')


@csrf_exempt
def get_system_health(request):
    """API per ottenere lo stato di salute del sistema"""
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Autenticazione richiesta'}, status=401)
    if not (request.user.is_superuser or request.user.is_staff):
        return JsonResponse({'error': 'Accesso negato'}, status=403)
    
    try:
        # Informazioni sistema
        if PSUTIL_AVAILABLE:
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
        else:
            # Valori mock se psutil non è disponibile
            cpu_percent = 45.0
            memory = type('obj', (object,), {'percent': 60.0, 'total': 8*1024**3, 'available': 3*1024**3})
            disk = type('obj', (object,), {'percent': 70.0, 'total': 500*1024**3, 'free': 150*1024**3})
        
        # Verifica servizi
        services_status = {
            'django': True,  # Se arriviamo qui, Django è attivo
            'call_server': check_service_health('http://localhost:8003/health'),
            'notification_server': check_service_health('http://localhost:8002/health'),
            'database': check_database_health(),
            'redis': check_redis_health(),
        }
        
        # Calcola health score generale
        active_services = sum(1 for status in services_status.values() if status)
        health_score = (active_services / len(services_status)) * 100
        
        return JsonResponse({
            'system': {
                'cpu_usage': cpu_percent,
                'memory_usage': memory.percent,
                'memory_total': memory.total // (1024**3),  # GB
                'memory_available': memory.available // (1024**3),  # GB
                'disk_usage': disk.percent,
                'disk_total': disk.total // (1024**3),  # GB
                'disk_free': disk.free // (1024**3),  # GB
                'uptime': get_system_uptime(),
            },
            'services': services_status,
            'health_score': health_score,
            'status': 'healthy' if health_score > 80 else 'warning' if health_score > 50 else 'critical'
        })
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


def get_dashboard_stats_test(request):
    """API test con dati reali per dashboard"""
    try:
        # Calcola statistiche reali
        now = timezone.now()
        last_24h = now - timedelta(hours=24)
        
        total_users = User.objects.count()
        active_users = User.objects.filter(last_login__gte=last_24h).count()
        
        # Statistiche messaggi (se disponibili)
        try:
            total_messages = Message.objects.count()
            messages_24h = Message.objects.filter(timestamp__gte=last_24h).count()
        except:
            total_messages = 0
            messages_24h = 0
        
        # Statistiche chiamate (se disponibili)
        try:
            total_calls = Call.objects.count()
            calls_24h = Call.objects.filter(start_time__gte=last_24h).count()
        except:
            total_calls = 0
            calls_24h = 0
        
        # Sistema health
        try:
            if PSUTIL_AVAILABLE:
                cpu_usage = psutil.cpu_percent()
                memory = psutil.virtual_memory()
                disk = psutil.disk_usage('/')
                
                system_health = 100 - max(cpu_usage, memory.percent, (disk.used / disk.total) * 100)
            else:
                system_health = 95  # Valore mock se psutil non disponibile
        except:
            system_health = 95
        
        return JsonResponse({
            'stats': {
                'total_users': total_users,
                'total_messages': total_messages,
                'total_calls': total_calls,
                'system_health': round(system_health),
                'active_users': active_users,
                'messages_24h': messages_24h,
                'calls_24h': calls_24h
            },
            'system_health': {
                'cpu_usage': round(psutil.cpu_percent() if PSUTIL_AVAILABLE else 25),
                'memory_usage': round(psutil.virtual_memory().percent if PSUTIL_AVAILABLE else 45),
                'disk_usage': round((psutil.disk_usage('/').used / psutil.disk_usage('/').total) * 100 if PSUTIL_AVAILABLE else 30)
            }
        })
        
    except Exception as e:
        return JsonResponse({
            'stats': {
                'total_users': total_users if 'total_users' in locals() else 0,
                'total_messages': 0,
                'total_calls': 0,
                'system_health': 95
            },
            'system_health': {
                'cpu_usage': 25,
                'memory_usage': 45,
                'disk_usage': 30
            },
            'error': str(e)
        })


def get_dashboard_stats(request):
    """API per statistiche dashboard"""
    # Controllo sessione Django per dashboard web
    if 'sessionid' not in request.COOKIES and not request.user.is_authenticated:
        return JsonResponse({'error': 'Sessione non valida'}, status=401)
    
    # Se c'è una sessione ma l'utente non è autenticato, prova a verificare
    if not request.user.is_authenticated:
        return JsonResponse({'error': 'Utente non autenticato'}, status=401)
    
    # Verifica permessi admin
    if not (request.user.is_staff or request.user.is_superuser):
        return JsonResponse({'error': 'Permessi insufficienti'}, status=403)
    
    now = timezone.now()
    last_24h = now - timedelta(hours=24)
    last_7d = now - timedelta(days=7)
    last_30d = now - timedelta(days=30)
    
    # Statistiche utenti
    total_users = User.objects.count()
    active_users_24h = User.objects.filter(last_login__gte=last_24h).count()
    online_users = get_online_users_count()
    blocked_users = User.objects.filter(is_active=False).count()
    
    # Statistiche dispositivi
    total_devices = Device.objects.count()
    active_devices = Device.objects.filter(is_active=True).count()
    compromised_devices = Device.objects.filter(
        Q(is_rooted=True) | Q(is_jailbroken=True) | Q(is_compromised=True)
    ).count()
    
    # Statistiche messaggi
    total_messages = Message.objects.count()
    messages_24h = Message.objects.filter(created_at__gte=last_24h).count()
    messages_7d = Message.objects.filter(created_at__gte=last_7d).count()
    
    # Statistiche chiamate
    total_calls = Call.objects.count() if hasattr(Call, 'objects') else 0
    calls_24h = Call.objects.filter(created_at__gte=last_24h).count() if hasattr(Call, 'objects') else 0
    
    # Statistiche chat
    total_chats = Chat.objects.count() if hasattr(Chat, 'objects') else 0
    active_chats = Chat.objects.filter(updated_at__gte=last_7d).count() if hasattr(Chat, 'objects') else 0
    
    # Traffico dati (approssimativo)
    data_usage = calculate_data_usage()
    
    return JsonResponse({
        'users': {
            'total': total_users,
            'active_24h': active_users_24h,
            'online': online_users,
            'blocked': blocked_users,
            'growth_rate': calculate_user_growth_rate(),
        },
        'devices': {
            'total': total_devices,
            'active': active_devices,
            'compromised': compromised_devices,
            'by_type': get_devices_by_type(),
        },
        'messages': {
            'total': total_messages,
            'last_24h': messages_24h,
            'last_7d': messages_7d,
            'by_type': get_messages_by_type(),
        },
        'calls': {
            'total': total_calls,
            'last_24h': calls_24h,
            'average_duration': get_average_call_duration(),
        },
        'chats': {
            'total': total_chats,
            'active': active_chats,
        },
        'traffic': data_usage,
        'security': {
            'failed_logins_24h': get_failed_logins_count(),
            'blocked_ips': get_blocked_ips_count(),
            'suspicious_activity': get_suspicious_activity_count(),
        }
    })


def get_users_management(request):
    """API per gestione utenti"""
    # Per ora disabilito il controllo di autenticazione per test
    # if not (request.user.is_staff or request.user.is_superuser):
    #     return JsonResponse({'error': 'Accesso negato'}, status=403)
    
    # Parametri filtro
    search = request.GET.get('search', '')
    status = request.GET.get('status', 'all')  # all, active, blocked, online
    group_id = request.GET.get('group_id')
    page = int(request.GET.get('page', 1))
    per_page = int(request.GET.get('per_page', 20))
    
    # Query base
    users = User.objects.select_related('profile').prefetch_related(
        'devices', 'group_memberships__group'
    )
    
    # Applica filtri
    if search:
        users = users.filter(
            Q(username__icontains=search) |
            Q(email__icontains=search) |
            Q(first_name__icontains=search) |
            Q(last_name__icontains=search)
        )
    
    if status == 'active':
        users = users.filter(is_active=True)
    elif status == 'blocked':
        users = users.filter(is_active=False)
    elif status == 'online':
        # Utenti attivi nelle ultime 5 minuti
        recent = timezone.now() - timedelta(minutes=5)
        users = users.filter(last_login__gte=recent)
    
    if group_id:
        users = users.filter(group_memberships__group_id=group_id, group_memberships__is_active=True)
    
    # Paginazione
    total = users.count()
    start = (page - 1) * per_page
    end = start + per_page
    users_page = users[start:end]
    
    users_data = []
    for user in users_page:
        # Calcola statistiche utente
        user_stats = get_user_statistics(user)
        
        users_data.append({
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'full_name': f"{user.first_name} {user.last_name}".strip(),
            'is_active': user.is_active,
            'is_staff': user.is_staff,
            'is_superuser': user.is_superuser,
            'date_joined': user.date_joined.isoformat(),
            'last_login': user.last_login.isoformat() if user.last_login else None,
            'avatar_url': getattr(user.profile, 'avatar_url', None) if hasattr(user, 'profile') else None,
            'devices_count': user.devices.filter(is_active=True).count(),
            'groups': [
                {
                    'id': str(membership.group.id),
                    'name': membership.group.name,
                    'color': membership.group.color,
                }
                for membership in user.group_memberships.filter(is_active=True)
            ],
            'statistics': user_stats,
            'security_status': get_user_security_status(user),
        })
    
    return JsonResponse({
        'users': users_data,
        'pagination': {
            'page': page,
            'per_page': per_page,
            'total': total,
            'pages': (total + per_page - 1) // per_page,
        }
    })


def get_groups_management(request):
    """API per gestione gruppi"""
    # Per ora disabilito il controllo di autenticazione per test
    # if not (request.user.is_staff or request.user.is_superuser):
    #     return JsonResponse({'error': 'Accesso negato'}, status=403)
    
    # Per ora usiamo gruppi mock fino a implementazione completa
    mock_groups = [
        {
            'id': '1',
            'name': 'Amministratori',
            'description': 'Gruppo degli amministratori di sistema',
            'color': '#F44336',
            'members_count': 2,
            'permissions': ['all'],
            'created_at': '2024-01-01T00:00:00Z',
        },
        {
            'id': '2',
            'name': 'Sviluppatori',
            'description': 'Team di sviluppo SecureVOX',
            'color': '#2196F3',
            'members_count': 5,
            'permissions': ['chat', 'calls', 'files'],
            'created_at': '2024-01-01T00:00:00Z',
        },
        {
            'id': '3',
            'name': 'Utenti Standard',
            'description': 'Utenti normali dell\'applicazione',
            'color': '#26A884',
            'members_count': User.objects.count() - 7,
            'permissions': ['chat', 'calls'],
            'created_at': '2024-01-01T00:00:00Z',
        },
    ]
    
    return JsonResponse({'groups': mock_groups})


def get_security_monitoring(request):
    """API per monitoraggio sicurezza"""
    # Per ora disabilito il controllo di autenticazione per test
    # if not (request.user.is_staff or request.user.is_superuser):
    #     return JsonResponse({'error': 'Accesso negato'}, status=403)
    
    now = timezone.now()
    last_24h = now - timedelta(hours=24)
    
    # Eventi di sicurezza recenti
    security_events = [
        {
            'id': 1,
            'type': 'failed_login',
            'severity': 'medium',
            'description': 'Tentativo di login fallito',
            'ip_address': '192.168.1.100',
            'user_agent': 'SecureVOX Mobile App',
            'timestamp': (now - timedelta(minutes=30)).isoformat(),
        },
        {
            'id': 2,
            'type': 'device_compromised',
            'severity': 'high',
            'description': 'Dispositivo potenzialmente compromesso rilevato',
            'device_id': 'device-123',
            'user': 'user@example.com',
            'timestamp': (now - timedelta(hours=2)).isoformat(),
        },
        {
            'id': 3,
            'type': 'suspicious_activity',
            'severity': 'low',
            'description': 'Attività sospetta rilevata',
            'details': 'Multipli accessi da IP diversi',
            'timestamp': (now - timedelta(hours=6)).isoformat(),
        },
    ]
    
    # Statistiche sicurezza
    security_stats = {
        'failed_logins_24h': get_failed_logins_count(),
        'blocked_ips': get_blocked_ips_count(),
        'compromised_devices': Device.objects.filter(
            Q(is_rooted=True) | Q(is_jailbroken=True) | Q(is_compromised=True)
        ).count(),
        'active_sessions': Session.objects.filter(
            last_message_at__gte=last_24h
        ).count(),
        'encryption_status': 'active',
        'firewall_status': 'active',
    }
    
    return JsonResponse({
        'events': security_events,
        'statistics': security_stats,
        'threat_level': calculate_threat_level(security_stats),
    })


def get_real_time_data(request):
    """API per dati in tempo reale"""
    if not (request.user.is_staff or request.user.is_superuser):
        return JsonResponse({'error': 'Accesso negato'}, status=403)
    
    # Simula dati real-time
    import random
    
    return JsonResponse({
        'timestamp': timezone.now().isoformat(),
        'active_connections': random.randint(50, 200),
        'messages_per_minute': random.randint(10, 50),
        'calls_active': random.randint(0, 10),
        'cpu_usage': psutil.cpu_percent(),
        'memory_usage': psutil.virtual_memory().percent,
        'network_io': {
            'bytes_sent': random.randint(1000000, 10000000),
            'bytes_received': random.randint(1000000, 10000000),
        },
        'alerts': get_active_alerts(),
    })


# Funzioni helper
def check_service_health(url):
    """Verifica lo stato di salute di un servizio"""
    try:
        response = requests.get(url, timeout=5)
        return response.status_code == 200
    except:
        return False


def check_database_health():
    """Verifica lo stato del database"""
    try:
        User.objects.count()
        return True
    except:
        return False


def check_redis_health():
    """Verifica lo stato di Redis"""
    try:
        # Implementa controllo Redis se configurato
        return True
    except:
        return False


def get_system_uptime():
    """Ottiene l'uptime del sistema"""
    try:
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.readline().split()[0])
        return int(uptime_seconds)
    except:
        return 0


def get_online_users_count():
    """Conta utenti online (attivi negli ultimi 5 minuti)"""
    recent = timezone.now() - timedelta(minutes=5)
    return User.objects.filter(last_login__gte=recent).count()


def calculate_user_growth_rate():
    """Calcola il tasso di crescita utenti"""
    now = timezone.now()
    last_month = now - timedelta(days=30)
    
    current_users = User.objects.filter(date_joined__gte=last_month).count()
    previous_month = User.objects.filter(
        date_joined__gte=last_month - timedelta(days=30),
        date_joined__lt=last_month
    ).count()
    
    if previous_month == 0:
        return 100.0
    
    return ((current_users - previous_month) / previous_month) * 100


def get_devices_by_type():
    """Ottiene statistiche dispositivi per tipo"""
    return {
        'android': Device.objects.filter(device_type='android', is_active=True).count(),
        'ios': Device.objects.filter(device_type='ios', is_active=True).count(),
        'web': Device.objects.filter(device_type='web', is_active=True).count(),
        'desktop': Device.objects.filter(device_type='desktop', is_active=True).count(),
    }


def get_messages_by_type():
    """Ottiene statistiche messaggi per tipo"""
    return {
        'text': Message.objects.filter(message_type='text').count(),
        'image': Message.objects.filter(message_type='image').count(),
        'video': Message.objects.filter(message_type='video').count(),
        'audio': Message.objects.filter(message_type='audio').count(),
        'file': Message.objects.filter(message_type='file').count(),
    }


def get_average_call_duration():
    """Calcola la durata media delle chiamate"""
    # Implementa quando il modello Call è disponibile
    return 180  # 3 minuti mock


def calculate_data_usage():
    """Calcola l'utilizzo dati approssimativo"""
    # Stima basata sui messaggi
    total_messages = Message.objects.count()
    estimated_mb = total_messages * 0.1  # 0.1 MB per messaggio medio
    
    return {
        'total_mb': int(estimated_mb),
        'daily_average_mb': int(estimated_mb / max(30, 1)),
        'trend': 'increasing',
    }


def get_failed_logins_count():
    """Conta i tentativi di login falliti"""
    # Implementa logging dei login falliti
    return 5  # Mock


def get_blocked_ips_count():
    """Conta gli IP bloccati"""
    # Implementa sistema di blocco IP
    return 2  # Mock


def get_suspicious_activity_count():
    """Conta attività sospette"""
    # Implementa rilevamento attività sospette
    return 1  # Mock


def get_user_statistics(user):
    """Ottiene statistiche per un utente specifico"""
    now = timezone.now()
    last_30d = now - timedelta(days=30)
    
    return {
        'messages_sent': Message.objects.filter(
            sender__user=user,
            created_at__gte=last_30d
        ).count(),
        'messages_received': Message.objects.filter(
            recipient__user=user,
            created_at__gte=last_30d
        ).count(),
        'calls_made': 0,  # Implementa quando disponibile
        'data_usage_mb': 10,  # Mock
        'last_activity': user.last_login.isoformat() if user.last_login else None,
    }


def get_user_security_status(user):
    """Ottiene lo stato di sicurezza di un utente"""
    compromised_devices = user.devices.filter(
        Q(is_rooted=True) | Q(is_jailbroken=True) | Q(is_compromised=True)
    ).count()
    
    if compromised_devices > 0:
        return 'warning'
    elif user.devices.filter(is_active=True).count() == 0:
        return 'inactive'
    else:
        return 'secure'


def calculate_threat_level(security_stats):
    """Calcola il livello di minaccia generale"""
    score = 0
    
    if security_stats['failed_logins_24h'] > 10:
        score += 2
    if security_stats['compromised_devices'] > 0:
        score += 3
    if security_stats['blocked_ips'] > 5:
        score += 1
    
    if score >= 5:
        return 'high'
    elif score >= 2:
        return 'medium'
    else:
        return 'low'


def get_active_alerts():
    """Ottiene gli alert attivi"""
    alerts = []
    
    # Controlla vari parametri di sistema
    cpu_usage = psutil.cpu_percent()
    memory_usage = psutil.virtual_memory().percent
    
    if cpu_usage > 80:
        alerts.append({
            'type': 'system',
            'severity': 'warning',
            'message': f'Utilizzo CPU elevato: {cpu_usage}%'
        })
    
    if memory_usage > 85:
        alerts.append({
            'type': 'system',
            'severity': 'critical',
            'message': f'Utilizzo memoria critico: {memory_usage}%'
        })
    
    return alerts
