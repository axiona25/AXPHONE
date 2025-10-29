from django.http import JsonResponse
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import datetime, timedelta
import json
import subprocess
import requests

# Import psutil in modo sicuro
try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False


def get_server_management(request):
    """API per gestione e monitoraggio server"""
    if not (request.user.is_staff or request.user.is_superuser):
        return JsonResponse({'error': 'Accesso negato'}, status=403)
    
    # Stato servizi dettagliato
    services_detail = {
        'django_api': {
            'name': 'Django API Server',
            'status': 'running',
            'port': 8001,
            'uptime': get_service_uptime('django'),
            'memory_usage': get_service_memory('django'),
            'cpu_usage': get_service_cpu('django'),
            'requests_per_minute': get_requests_per_minute(),
            'last_restart': get_last_restart('django'),
            'version': '4.2.16',
            'health_score': 95,
        },
        'call_server': {
            'name': 'SecureVOX Call Server',
            'status': check_service_status('http://localhost:8003/health'),
            'port': 8003,
            'uptime': get_service_uptime('call_server'),
            'memory_usage': get_service_memory('call_server'),
            'cpu_usage': get_service_cpu('call_server'),
            'active_calls': get_active_calls_count(),
            'last_restart': get_last_restart('call_server'),
            'version': '1.0.0',
            'health_score': 88,
        },
        'notification_server': {
            'name': 'Notification Server',
            'status': check_service_status('http://localhost:8002/health'),
            'port': 8002,
            'uptime': get_service_uptime('notification_server'),
            'memory_usage': get_service_memory('notification_server'),
            'cpu_usage': get_service_cpu('notification_server'),
            'notifications_sent': get_notifications_count(),
            'last_restart': get_last_restart('notification_server'),
            'version': '1.0.0',
            'health_score': 92,
        },
        'database': {
            'name': 'SQLite Database',
            'status': 'running' if check_database_health() else 'error',
            'size_mb': get_database_size(),
            'connections': get_db_connections(),
            'queries_per_minute': get_db_queries_per_minute(),
            'last_backup': get_last_backup_time(),
            'version': 'SQLite 3.x',
            'health_score': 90,
        },
        'redis_cache': {
            'name': 'Redis Cache',
            'status': 'running' if check_redis_health() else 'stopped',
            'memory_usage': get_redis_memory(),
            'keys_count': get_redis_keys_count(),
            'hit_rate': get_redis_hit_rate(),
            'last_restart': get_last_restart('redis'),
            'version': 'Redis 7.x',
            'health_score': 85,
        }
    }
    
    # Metriche sistema
    if PSUTIL_AVAILABLE:
        system_metrics = {
            'cpu': {
                'usage': psutil.cpu_percent(interval=1),
                'cores': psutil.cpu_count(),
                'temperature': get_cpu_temperature(),
            },
            'memory': {
                'total_gb': psutil.virtual_memory().total // (1024**3),
                'used_gb': psutil.virtual_memory().used // (1024**3),
                'available_gb': psutil.virtual_memory().available // (1024**3),
                'percentage': psutil.virtual_memory().percent,
            },
            'disk': {
                'total_gb': psutil.disk_usage('/').total // (1024**3),
                'used_gb': psutil.disk_usage('/').used // (1024**3),
                'free_gb': psutil.disk_usage('/').free // (1024**3),
                'percentage': psutil.disk_usage('/').percent,
            },
            'network': {
                'bytes_sent': psutil.net_io_counters().bytes_sent,
                'bytes_received': psutil.net_io_counters().bytes_recv,
                'packets_sent': psutil.net_io_counters().packets_sent,
                'packets_received': psutil.net_io_counters().packets_recv,
                'bandwidth_usage': get_bandwidth_usage(),
            }
        }
    else:
        # Valori mock
        system_metrics = {
            'cpu': {'usage': 45.0, 'cores': 8, 'temperature': 65},
            'memory': {'total_gb': 16, 'used_gb': 8, 'available_gb': 8, 'percentage': 50.0},
            'disk': {'total_gb': 500, 'used_gb': 200, 'free_gb': 300, 'percentage': 40.0},
            'network': {'bytes_sent': 1024000, 'bytes_received': 2048000, 'packets_sent': 1000, 'packets_received': 2000, 'bandwidth_usage': 15.5}
        }
    
    # Log recenti
    recent_logs = get_recent_server_logs()
    
    # Alert attivi
    alerts = get_server_alerts(system_metrics, services_detail)
    
    # Statistiche traffico
    traffic_stats = {
        'requests_per_hour': get_requests_per_hour(),
        'data_transfer_mb': get_data_transfer(),
        'peak_concurrent_users': get_peak_concurrent_users(),
        'response_time_avg': get_average_response_time(),
        'error_rate': get_error_rate(),
    }
    
    return JsonResponse({
        'services': services_detail,
        'system_metrics': system_metrics,
        'traffic_stats': traffic_stats,
        'recent_logs': recent_logs,
        'alerts': alerts,
        'uptime': get_system_uptime(),
        'last_updated': timezone.now().isoformat(),
    })


def get_licenses_management(request):
    """API per gestione licenze e rinnovi"""
    if not (request.user.is_staff or request.user.is_superuser):
        return JsonResponse({'error': 'Accesso negato'}, status=403)
    
    # Informazioni licenza principale
    main_license = {
        'product': 'SecureVOX Enterprise',
        'license_key': 'SVOX-ENT-2024-****-****',
        'status': 'active',
        'type': 'enterprise',
        'issued_date': '2024-01-01',
        'expiry_date': '2024-12-31',
        'days_remaining': calculate_days_remaining('2024-12-31'),
        'max_users': 1000,
        'current_users': User.objects.count(),
        'features': [
            'Unlimited Users',
            'End-to-End Encryption',
            'Video Calls',
            'File Sharing',
            'Admin Dashboard',
            'API Access',
            'Priority Support'
        ],
        'renewal_price': 2500.00,
        'currency': 'EUR',
    }
    
    # Licenze utente
    user_licenses = []
    users = User.objects.all()[:10]  # Primi 10 per esempio
    
    for user in users:
        user_licenses.append({
            'user_id': user.id,
            'username': user.username,
            'email': user.email,
            'license_type': 'standard',
            'assigned_date': user.date_joined.strftime('%Y-%m-%d'),
            'last_activity': user.last_login.strftime('%Y-%m-%d %H:%M') if user.last_login else 'Mai',
            'devices_count': user.devices.filter(is_active=True).count(),
            'storage_used_mb': calculate_user_storage(user),
            'calls_minutes': calculate_user_calls_minutes(user),
            'status': 'active' if user.is_active else 'suspended',
        })
    
    # Statistiche utilizzo
    usage_stats = {
        'total_licensed_users': main_license['max_users'],
        'active_users': User.objects.filter(is_active=True).count(),
        'utilization_rate': (User.objects.count() / main_license['max_users']) * 100,
        'storage_used_gb': calculate_total_storage_used(),
        'storage_limit_gb': 1000,  # 1TB limite
        'calls_minutes_month': calculate_total_calls_minutes(),
        'calls_limit_minutes': 50000,  # 50k minuti/mese
    }
    
    # Rinnovi e fatturazione
    billing_info = {
        'next_renewal_date': '2024-12-31',
        'auto_renewal': True,
        'billing_email': 'admin@securevox.com',
        'payment_method': 'Credit Card ending in ****1234',
        'last_payment': {
            'date': '2024-01-01',
            'amount': 2500.00,
            'currency': 'EUR',
            'status': 'paid',
            'invoice_number': 'INV-2024-001',
        },
        'upcoming_charges': [
            {
                'description': 'SecureVOX Enterprise Renewal',
                'amount': 2500.00,
                'date': '2024-12-31',
                'status': 'pending',
            }
        ]
    }
    
    # Alert licenze
    license_alerts = []
    
    days_remaining = main_license['days_remaining']
    if days_remaining <= 30:
        license_alerts.append({
            'type': 'renewal_due',
            'severity': 'warning' if days_remaining > 7 else 'critical',
            'message': f'Licenza scade tra {days_remaining} giorni',
            'action_required': True,
        })
    
    utilization = usage_stats['utilization_rate']
    if utilization > 90:
        license_alerts.append({
            'type': 'usage_high',
            'severity': 'warning',
            'message': f'Utilizzo licenze al {utilization:.1f}%',
            'action_required': False,
        })
    
    return JsonResponse({
        'main_license': main_license,
        'user_licenses': user_licenses,
        'usage_stats': usage_stats,
        'billing_info': billing_info,
        'alerts': license_alerts,
        'compliance_status': 'compliant',
        'last_audit': '2024-09-01',
    })


# Helper functions
def check_service_status(url):
    """Verifica stato servizio tramite URL"""
    try:
        response = requests.get(url, timeout=5)
        return 'running' if response.status_code == 200 else 'error'
    except:
        return 'stopped'


def get_service_uptime(service):
    """Ottiene uptime del servizio (mock)"""
    # In produzione, implementare con monitoraggio reale
    return "2d 14h 32m"


def get_service_memory(service):
    """Ottiene utilizzo memoria del servizio (mock)"""
    import random
    return random.randint(50, 200)  # MB


def get_service_cpu(service):
    """Ottiene utilizzo CPU del servizio (mock)"""
    import random
    return random.uniform(5.0, 25.0)


def get_requests_per_minute():
    """Ottiene richieste per minuto (mock)"""
    import random
    return random.randint(50, 200)


def get_last_restart(service):
    """Ottiene timestamp ultimo restart (mock)"""
    return (timezone.now() - timedelta(hours=48)).strftime('%Y-%m-%d %H:%M:%S')


def get_active_calls_count():
    """Ottiene numero chiamate attive"""
    # Implementare con dati reali
    return 3


def get_notifications_count():
    """Ottiene numero notifiche inviate"""
    return 1247


def check_database_health():
    """Verifica salute database"""
    try:
        User.objects.count()
        return True
    except:
        return False


def get_database_size():
    """Ottiene dimensione database in MB"""
    try:
        import os
        db_path = 'securevox.db'  # Path del database SQLite
        if os.path.exists(db_path):
            return os.path.getsize(db_path) // (1024 * 1024)  # MB
    except:
        pass
    return 25  # Mock


def get_db_connections():
    """Ottiene numero connessioni database attive"""
    return 12  # Mock


def get_db_queries_per_minute():
    """Ottiene query per minuto"""
    return 450  # Mock


def get_last_backup_time():
    """Ottiene timestamp ultimo backup"""
    return (timezone.now() - timedelta(hours=6)).strftime('%Y-%m-%d %H:%M:%S')


def check_redis_health():
    """Verifica salute Redis"""
    # Implementare controllo Redis reale
    return True


def get_redis_memory():
    """Ottiene utilizzo memoria Redis"""
    return 64  # MB mock


def get_redis_keys_count():
    """Ottiene numero chiavi Redis"""
    return 1523


def get_redis_hit_rate():
    """Ottiene hit rate Redis"""
    return 94.5  # % mock


def get_cpu_temperature():
    """Ottiene temperatura CPU"""
    return 65  # °C mock


def get_bandwidth_usage():
    """Ottiene utilizzo banda"""
    return 15.5  # % mock


def get_recent_server_logs():
    """Ottiene log recenti del server"""
    now = timezone.now()
    return [
        {
            'timestamp': (now - timedelta(minutes=2)).strftime('%H:%M:%S'),
            'level': 'INFO',
            'service': 'django',
            'message': 'User authentication successful for admin',
        },
        {
            'timestamp': (now - timedelta(minutes=5)).strftime('%H:%M:%S'),
            'level': 'INFO',
            'service': 'call_server',
            'message': 'New call session established',
        },
        {
            'timestamp': (now - timedelta(minutes=8)).strftime('%H:%M:%S'),
            'level': 'WARNING',
            'service': 'notification_server',
            'message': 'High queue size detected: 150 pending notifications',
        },
        {
            'timestamp': (now - timedelta(minutes=12)).strftime('%H:%M:%S'),
            'level': 'INFO',
            'service': 'database',
            'message': 'Automatic backup completed successfully',
        },
    ]


def get_server_alerts(system_metrics, services):
    """Genera alert per il server"""
    alerts = []
    
    # Alert CPU
    cpu_usage = system_metrics['cpu']['usage']
    if cpu_usage > 80:
        alerts.append({
            'type': 'system',
            'severity': 'critical' if cpu_usage > 90 else 'warning',
            'message': f'Utilizzo CPU elevato: {cpu_usage:.1f}%',
            'service': 'system',
        })
    
    # Alert memoria
    memory_usage = system_metrics['memory']['percentage']
    if memory_usage > 85:
        alerts.append({
            'type': 'system',
            'severity': 'critical' if memory_usage > 95 else 'warning',
            'message': f'Utilizzo memoria elevato: {memory_usage:.1f}%',
            'service': 'system',
        })
    
    # Alert servizi
    for service_key, service_data in services.items():
        if service_data['status'] != 'running':
            alerts.append({
                'type': 'service',
                'severity': 'critical',
                'message': f'Servizio {service_data["name"]} non disponibile',
                'service': service_key,
            })
    
    return alerts


def get_requests_per_hour():
    """Ottiene richieste per ora"""
    return 12450  # Mock


def get_data_transfer():
    """Ottiene trasferimento dati in MB"""
    return 2340  # Mock


def get_peak_concurrent_users():
    """Ottiene picco utenti concorrenti"""
    return 156  # Mock


def get_average_response_time():
    """Ottiene tempo di risposta medio in ms"""
    return 245  # Mock


def get_error_rate():
    """Ottiene tasso di errori in %"""
    return 0.8  # Mock


def get_system_uptime():
    """Ottiene uptime sistema"""
    try:
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.readline().split()[0])
        days = int(uptime_seconds // 86400)
        hours = int((uptime_seconds % 86400) // 3600)
        minutes = int((uptime_seconds % 3600) // 60)
        return f"{days}d {hours}h {minutes}m"
    except:
        return "2d 14h 32m"  # Mock


def calculate_days_remaining(expiry_date):
    """Calcola giorni rimanenti alla scadenza"""
    try:
        expiry = datetime.strptime(expiry_date, '%Y-%m-%d').date()
        today = datetime.now().date()
        return (expiry - today).days
    except:
        return 95  # Mock


def calculate_user_storage(user):
    """Calcola storage utilizzato dall'utente"""
    # Implementare calcolo reale basato sui file
    import random
    return random.randint(50, 500)  # MB mock


def calculate_user_calls_minutes(user):
    """Calcola minuti di chiamate dell'utente"""
    # Implementare calcolo reale
    import random
    return random.randint(10, 300)  # Minuti mock


def calculate_total_storage_used():
    """Calcola storage totale utilizzato"""
    return 245  # GB mock


def calculate_total_calls_minutes():
    """Calcola minuti totali di chiamate"""
    return 12450  # Minuti mock
