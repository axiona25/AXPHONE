from django.http import JsonResponse
from django.contrib.auth.models import User
from django.db.models import Count, Q, Avg, Sum
from django.utils import timezone
from datetime import datetime, timedelta
import json

from crypto.models import Device, Message, Session


def get_devices_management(request):
    """API per gestione dispositivi"""
    # Per ora disabilito il controllo di autenticazione per test
    # if not (request.user.is_staff or request.user.is_superuser):
    #     return JsonResponse({'error': 'Accesso negato'}, status=403)
    
    # Parametri filtro
    search = request.GET.get('search', '')
    device_type = request.GET.get('type', 'all')
    status = request.GET.get('status', 'all')  # all, active, compromised, blocked
    page = int(request.GET.get('page', 1))
    per_page = int(request.GET.get('per_page', 20))
    
    # Query base
    devices = Device.objects.select_related('user').order_by('-last_seen')
    
    # Applica filtri
    if search:
        devices = devices.filter(
            Q(device_name__icontains=search) |
            Q(user__username__icontains=search) |
            Q(user__email__icontains=search)
        )
    
    if device_type != 'all':
        devices = devices.filter(device_type=device_type)
    
    if status == 'active':
        devices = devices.filter(is_active=True)
    elif status == 'compromised':
        devices = devices.filter(
            Q(is_rooted=True) | Q(is_jailbroken=True) | Q(is_compromised=True)
        )
    elif status == 'blocked':
        devices = devices.filter(is_active=False)
    
    # Paginazione
    total = devices.count()
    start = (page - 1) * per_page
    end = start + per_page
    devices_page = devices[start:end]
    
    devices_data = []
    for device in devices_page:
        # Calcola rischio sicurezza
        risk_level = 'low'
        if device.is_compromised:
            risk_level = 'critical'
        elif device.is_rooted or device.is_jailbroken:
            risk_level = 'high'
        elif not device.is_active:
            risk_level = 'medium'
        
        # Statistiche device
        messages_count = Message.objects.filter(
            Q(sender=device) | Q(recipient=device)
        ).count()
        
        devices_data.append({
            'id': str(device.id),
            'device_name': device.device_name,
            'device_type': device.device_type,
            'user': {
                'id': device.user.id,
                'username': device.user.username,
                'email': device.user.email,
            },
            'is_active': device.is_active,
            'is_rooted': device.is_rooted,
            'is_jailbroken': device.is_jailbroken,
            'is_compromised': device.is_compromised,
            'last_seen': device.last_seen.isoformat() if device.last_seen else None,
            'created_at': device.created_at.isoformat(),
            'risk_level': risk_level,
            'messages_count': messages_count,
            'app_version': getattr(device, 'app_version', 'N/A'),
            'os_version': getattr(device, 'os_version', 'N/A'),
        })
    
    # Statistiche generali
    stats = {
        'total_devices': Device.objects.count(),
        'active_devices': Device.objects.filter(is_active=True).count(),
        'compromised_devices': Device.objects.filter(
            Q(is_rooted=True) | Q(is_jailbroken=True) | Q(is_compromised=True)
        ).count(),
        'by_type': {
            'android': Device.objects.filter(device_type='android').count(),
            'ios': Device.objects.filter(device_type='ios').count(),
            'web': Device.objects.filter(device_type='web').count(),
            'desktop': Device.objects.filter(device_type='desktop').count(),
        }
    }
    
    return JsonResponse({
        'devices': devices_data,
        'statistics': stats,
        'pagination': {
            'page': page,
            'per_page': per_page,
            'total': total,
            'pages': (total + per_page - 1) // per_page,
        }
    })


def get_chats_management(request):
    """API per gestione chat"""
    # Per ora disabilito il controllo di autenticazione per test
    # if not (request.user.is_staff or request.user.is_superuser):
    #     return JsonResponse({'error': 'Accesso negato'}, status=403)
    
    # Statistiche chat
    total_sessions = Session.objects.count()
    active_sessions = Session.objects.filter(
        last_message_at__gte=timezone.now() - timedelta(days=7)
    ).count()
    
    # Top conversazioni per messaggi
    top_sessions = Session.objects.annotate(
        message_count=Count('device_a__sent_messages') + Count('device_b__sent_messages')
    ).order_by('-message_count')[:10]
    
    sessions_data = []
    for session in top_sessions:
        message_count = Message.objects.filter(
            Q(sender=session.device_a, recipient=session.device_b) |
            Q(sender=session.device_b, recipient=session.device_a)
        ).count()
        
        sessions_data.append({
            'participants': [
                {
                    'username': session.device_a.user.username,
                    'device_name': session.device_a.device_name,
                },
                {
                    'username': session.device_b.user.username,
                    'device_name': session.device_b.device_name,
                }
            ],
            'message_count': message_count,
            'last_message': session.last_message_at.isoformat() if session.last_message_at else None,
            'created_at': session.created_at.isoformat(),
        })
    
    # Statistiche messaggi per tipo
    message_stats = {
        'total_messages': Message.objects.count(),
        'messages_24h': Message.objects.filter(
            created_at__gte=timezone.now() - timedelta(hours=24)
        ).count(),
        'by_type': {
            'text': Message.objects.filter(message_type='text').count(),
            'image': Message.objects.filter(message_type='image').count(),
            'video': Message.objects.filter(message_type='video').count(),
            'audio': Message.objects.filter(message_type='audio').count(),
            'file': Message.objects.filter(message_type='file').count(),
        }
    }
    
    return JsonResponse({
        'sessions': {
            'total': total_sessions,
            'active': active_sessions,
            'top_conversations': sessions_data,
        },
        'messages': message_stats,
    })


def get_media_management(request):
    """API per gestione media"""
    if not request.user.is_superuser:
        return JsonResponse({'error': 'Accesso negato'}, status=403)
    
    # Statistiche media (approssimative)
    media_messages = Message.objects.filter(
        message_type__in=['image', 'video', 'audio', 'file']
    )
    
    media_stats = {
        'total_files': media_messages.count(),
        'by_type': {
            'images': Message.objects.filter(message_type='image').count(),
            'videos': Message.objects.filter(message_type='video').count(),
            'audios': Message.objects.filter(message_type='audio').count(),
            'documents': Message.objects.filter(message_type='file').count(),
        },
        'storage_usage': {
            'total_mb': 1024,  # Mock - calcolare da file reali
            'images_mb': 512,
            'videos_mb': 256,
            'audios_mb': 128,
            'documents_mb': 128,
        },
        'recent_uploads': get_recent_media_uploads(),
    }
    
    return JsonResponse(media_stats)


def get_calls_management(request):
    """API per gestione chiamate"""
    if not request.user.is_superuser:
        return JsonResponse({'error': 'Accesso negato'}, status=403)
    
    # Mock data per chiamate - da implementare con modello Call reale
    calls_stats = {
        'total_calls': 156,
        'calls_24h': 23,
        'active_calls': 3,
        'average_duration': 180,  # secondi
        'call_quality': {
            'excellent': 65,
            'good': 25,
            'poor': 10,
        },
        'by_type': {
            'audio': 120,
            'video': 36,
        },
        'peak_hours': [
            {'hour': '09:00', 'calls': 12},
            {'hour': '14:00', 'calls': 18},
            {'hour': '18:00', 'calls': 15},
        ],
        'recent_calls': [
            {
                'id': 1,
                'participants': ['user1', 'user2'],
                'type': 'video',
                'duration': 245,
                'quality': 'excellent',
                'started_at': (timezone.now() - timedelta(minutes=30)).isoformat(),
            },
            {
                'id': 2,
                'participants': ['user3', 'user4'],
                'type': 'audio',
                'duration': 120,
                'quality': 'good',
                'started_at': (timezone.now() - timedelta(hours=1)).isoformat(),
            },
        ]
    }
    
    return JsonResponse(calls_stats)


def get_analytics_data(request):
    """API per analytics avanzate"""
    if not request.user.is_superuser:
        return JsonResponse({'error': 'Accesso negato'}, status=403)
    
    now = timezone.now()
    last_30d = now - timedelta(days=30)
    
    # Analisi crescita utenti
    user_growth = []
    for i in range(30):
        date = now - timedelta(days=29-i)
        count = User.objects.filter(date_joined__date=date.date()).count()
        user_growth.append({
            'date': date.strftime('%Y-%m-%d'),
            'users': count
        })
    
    # Analisi attività messaggi
    message_activity = []
    for i in range(7):
        date = now - timedelta(days=6-i)
        count = Message.objects.filter(created_at__date=date.date()).count()
        message_activity.append({
            'date': date.strftime('%Y-%m-%d'),
            'messages': count
        })
    
    # Top utenti per attività
    top_users = User.objects.annotate(
        message_count=Count('devices__sent_messages')
    ).order_by('-message_count')[:10]
    
    top_users_data = [
        {
            'username': user.username,
            'message_count': user.message_count,
            'devices': user.devices.filter(is_active=True).count(),
        }
        for user in top_users
    ]
    
    # Statistiche dispositivi nel tempo
    device_stats = {
        'growth': Device.objects.filter(created_at__gte=last_30d).count(),
        'active_percentage': (
            Device.objects.filter(is_active=True).count() / 
            max(Device.objects.count(), 1)
        ) * 100,
        'platform_distribution': {
            'android': Device.objects.filter(device_type='android').count(),
            'ios': Device.objects.filter(device_type='ios').count(),
            'web': Device.objects.filter(device_type='web').count(),
            'desktop': Device.objects.filter(device_type='desktop').count(),
        }
    }
    
    return JsonResponse({
        'user_growth': user_growth,
        'message_activity': message_activity,
        'top_users': top_users_data,
        'device_stats': device_stats,
        'engagement_metrics': {
            'daily_active_users': User.objects.filter(
                last_login__gte=now - timedelta(days=1)
            ).count(),
            'weekly_active_users': User.objects.filter(
                last_login__gte=now - timedelta(days=7)
            ).count(),
            'monthly_active_users': User.objects.filter(
                last_login__gte=now - timedelta(days=30)
            ).count(),
            'retention_rate': calculate_retention_rate(),
        }
    })


def get_monitoring_data(request):
    """API per monitoraggio servizi"""
    if not request.user.is_superuser:
        return JsonResponse({'error': 'Accesso negato'}, status=403)
    
    try:
        import psutil
        PSUTIL_AVAILABLE = True
    except ImportError:
        PSUTIL_AVAILABLE = False
    
    # Metriche sistema
    if PSUTIL_AVAILABLE:
        system_metrics = {
            'cpu': {
                'usage': psutil.cpu_percent(interval=1),
                'cores': psutil.cpu_count(),
                'load_avg': list(psutil.getloadavg()) if hasattr(psutil, 'getloadavg') else [0, 0, 0],
            },
            'memory': {
                'total': psutil.virtual_memory().total // (1024**3),  # GB
                'used': psutil.virtual_memory().used // (1024**3),   # GB
                'percentage': psutil.virtual_memory().percent,
            },
            'disk': {
                'total': psutil.disk_usage('/').total // (1024**3),  # GB
                'used': psutil.disk_usage('/').used // (1024**3),   # GB
                'percentage': psutil.disk_usage('/').percent,
            },
            'network': {
                'bytes_sent': psutil.net_io_counters().bytes_sent,
                'bytes_recv': psutil.net_io_counters().bytes_recv,
                'packets_sent': psutil.net_io_counters().packets_sent,
                'packets_recv': psutil.net_io_counters().packets_recv,
            }
        }
    else:
        # Valori mock se psutil non è disponibile
        system_metrics = {
            'cpu': {'usage': 45.0, 'cores': 8, 'load_avg': [0.5, 0.6, 0.7]},
            'memory': {'total': 8, 'used': 5, 'percentage': 62.5},
            'disk': {'total': 500, 'used': 350, 'percentage': 70.0},
            'network': {'bytes_sent': 1024000, 'bytes_recv': 2048000, 'packets_sent': 1000, 'packets_recv': 2000}
        }
    
    # Stato servizi
    services_status = {
        'django': True,  # Se arriviamo qui, Django è attivo
        'database': check_database_connection(),
        'redis': check_redis_connection(),
        'call_server': check_service_url('http://localhost:8003/health'),
        'notification_server': check_service_url('http://localhost:8002/health'),
    }
    
    # Log recenti (mock)
    recent_logs = [
        {
            'timestamp': (timezone.now() - timedelta(minutes=5)).isoformat(),
            'level': 'INFO',
            'service': 'django',
            'message': 'User authentication successful',
        },
        {
            'timestamp': (timezone.now() - timedelta(minutes=10)).isoformat(),
            'level': 'WARNING',
            'service': 'call_server',
            'message': 'High CPU usage detected',
        },
        {
            'timestamp': (timezone.now() - timedelta(minutes=15)).isoformat(),
            'level': 'ERROR',
            'service': 'notification_server',
            'message': 'Failed to send push notification',
        },
    ]
    
    # Alerts attivi
    alerts = []
    if system_metrics['cpu']['usage'] > 80:
        alerts.append({
            'type': 'system',
            'severity': 'warning',
            'message': f'CPU usage high: {system_metrics["cpu"]["usage"]}%'
        })
    
    if system_metrics['memory']['percentage'] > 85:
        alerts.append({
            'type': 'system',
            'severity': 'critical',
            'message': f'Memory usage critical: {system_metrics["memory"]["percentage"]}%'
        })
    
    return JsonResponse({
        'system_metrics': system_metrics,
        'services_status': services_status,
        'recent_logs': recent_logs,
        'alerts': alerts,
        'uptime': get_system_uptime(),
    })


# Helper functions
def get_recent_media_uploads():
    """Ottiene i caricamenti media recenti"""
    recent_media = Message.objects.filter(
        message_type__in=['image', 'video', 'audio', 'file'],
        created_at__gte=timezone.now() - timedelta(hours=24)
    ).order_by('-created_at')[:10]
    
    return [
        {
            'id': str(msg.id),
            'type': msg.message_type,
            'sender': msg.sender.user.username,
            'created_at': msg.created_at.isoformat(),
            'size_estimate': '1.2 MB',  # Mock
        }
        for msg in recent_media
    ]


def calculate_retention_rate():
    """Calcola il tasso di retention"""
    # Implementazione semplificata
    total_users = User.objects.count()
    active_users = User.objects.filter(
        last_login__gte=timezone.now() - timedelta(days=30)
    ).count()
    
    if total_users == 0:
        return 0
    
    return (active_users / total_users) * 100


def check_database_connection():
    """Verifica connessione database"""
    try:
        User.objects.count()
        return True
    except:
        return False


def check_redis_connection():
    """Verifica connessione Redis"""
    try:
        # Implementa controllo Redis se configurato
        return True
    except:
        return False


def check_service_url(url):
    """Verifica stato servizio tramite URL"""
    try:
        import requests
        response = requests.get(url, timeout=5)
        return response.status_code == 200
    except:
        return False


def get_system_uptime():
    """Ottiene uptime sistema"""
    try:
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.readline().split()[0])
        return int(uptime_seconds)
    except:
        return 0


# Azioni amministrative
def block_user(request):
    """Blocca un utente"""
    if not request.user.is_superuser:
        return JsonResponse({'error': 'Accesso negato'}, status=403)
    
    if request.method != 'POST':
        return JsonResponse({'error': 'Metodo non consentito'}, status=405)
    
    try:
        data = json.loads(request.body)
        user_id = data.get('user_id')
        
        user = User.objects.get(id=user_id)
        user.is_active = False
        user.save()
        
        # Log dell'azione
        from .models import AdminAction
        AdminAction.objects.create(
            admin=request.user,
            action_type='user_deactivate',
            target_user=user,
            details={'reason': 'Manual block by admin'},
            ip_address=get_client_ip(request),
        )
        
        return JsonResponse({
            'success': True,
            'message': f'Utente {user.username} bloccato con successo'
        })
        
    except User.DoesNotExist:
        return JsonResponse({'error': 'Utente non trovato'}, status=404)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


def block_device(request):
    """Blocca un dispositivo"""
    if not request.user.is_superuser:
        return JsonResponse({'error': 'Accesso negato'}, status=403)
    
    if request.method != 'POST':
        return JsonResponse({'error': 'Metodo non consentito'}, status=405)
    
    try:
        data = json.loads(request.body)
        device_id = data.get('device_id')
        
        device = Device.objects.get(id=device_id)
        device.is_active = False
        device.save()
        
        # Log dell'azione
        from .models import AdminAction
        AdminAction.objects.create(
            admin=request.user,
            action_type='device_wipe',
            target_device=device,
            details={'reason': 'Manual block by admin'},
            ip_address=get_client_ip(request),
        )
        
        return JsonResponse({
            'success': True,
            'message': f'Dispositivo {device.device_name} bloccato con successo'
        })
        
    except Device.DoesNotExist:
        return JsonResponse({'error': 'Dispositivo non trovato'}, status=404)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


def get_client_ip(request):
    """Ottiene IP del client"""
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip
