import os
import subprocess
import signal
import json
import psutil
import time
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.contrib.auth.decorators import user_passes_test
import logging

logger = logging.getLogger(__name__)


def is_superuser(user):
    """Verifica che l'utente sia superuser o staff"""
    return user.is_authenticated and (user.is_superuser or user.is_staff)


# Configurazione servizi con specifiche tecniche dettagliate
SERVICES_CONFIG = {
    'django_api': {
        'name': 'Django API Server',
        'description': 'Server principale API REST con Django Framework',
        'port': 8001,
        'start_command': 'cd /Users/r.amoroso/Desktop/securevox-complete-cursor-pack/server && source venv/bin/activate && python manage.py runserver 0.0.0.0:8001',
        'health_url': 'http://localhost:8001/health/',
        'log_file': '/var/log/securevox/django.log',
        'icon': 'fa-server',
        'color': '#26A884',
        'tech_specs': {
            'framework': 'Django 4.2.16',
            'language': 'Python 3.11+',
            'database': 'SQLite / PostgreSQL',
            'cache': 'Redis / LocMem',
            'server': 'Gunicorn (prod) / Django Dev Server',
            'api': 'Django REST Framework 3.15.2',
            'authentication': 'JWT + Session Auth',
            'encryption': 'AES-256-GCM, X3DH, Double Ratchet',
            'features': [
                'API REST complete',
                'Autenticazione sicura',
                'Chat E2EE',
                'Gestione dispositivi',
                'Upload/Download file',
                'Admin panel integrato',
                'Sistema distribuzione app'
            ],
            'dependencies': [
                'djangorestframework',
                'django-cors-headers',
                'PyNaCl (crittografia)',
                'cryptography',
                'firebase-admin',
                'celery (task asincroni)'
            ],
            'performance': {
                'max_concurrent_users': '1000+',
                'avg_response_time': '< 200ms',
                'throughput': '500+ req/sec',
                'memory_usage': '200-500MB',
            }
        }
    },
    'call_server': {
        'name': 'SecureVOX Call Server',
        'description': 'Server WebRTC per signaling chiamate audio/video',
        'port': 8003,
        'start_command': 'cd /Users/r.amoroso/Desktop/securevox-complete-cursor-pack/call-server && PORT=8003 JWT_SECRET=test-secret NODE_ENV=development HOST=0.0.0.0 MAIN_SERVER_URL=http://localhost:8001 NOTIFY_SERVER_URL=http://localhost:8002 node src/server.js',
        'health_url': 'http://localhost:8003/health/',
        'log_file': '/var/log/securevox/call-server.log',
        'icon': 'fa-phone',
        'color': '#2196F3',
        'tech_specs': {
            'framework': 'Express.js + Socket.IO',
            'language': 'Node.js 18+',
            'protocol': 'WebRTC + DTLS-SRTP',
            'signaling': 'Socket.IO WebSocket',
            'encryption': 'SFrame E2EE',
            'turn_server': 'Coturn (NAT traversal)',
            'sfu': 'Janus Gateway (group calls)',
            'features': [
                'Chiamate audio/video 1:1',
                'Chiamate di gruppo (SFU)',
                'ICE candidate exchange',
                'TURN/STUN server integration',
                'E2EE con SFrame',
                'Qualità adattiva',
                'Recording chiamate (opzionale)'
            ],
            'dependencies': [
                'express',
                'socket.io',
                'jsonwebtoken',
                'cors',
                'node-fetch'
            ],
            'performance': {
                'max_concurrent_calls': '100+',
                'latency': '< 50ms',
                'bandwidth': '1-5 Mbps per call',
                'memory_usage': '100-300MB',
            }
        }
    },
    'notification_server': {
        'name': 'Notification Server',
        'description': 'Server notifiche push multipiattaforma e WebSocket real-time',
        'port': 8002,
        'start_command': 'cd /Users/r.amoroso/Desktop/securevox-complete-cursor-pack/server && source venv/bin/activate && python securevox_notify.py',
        'health_url': 'http://localhost:8002/health/',
        'log_file': '/var/log/securevox/notifications.log',
        'icon': 'fa-bell',
        'color': '#FF9800',
        'tech_specs': {
            'framework': 'Python WebSocket + HTTP Server',
            'language': 'Python 3.11+',
            'protocols': 'WebSocket, HTTP REST',
            'push_services': 'Firebase FCM, Apple APNS',
            'encryption': 'Payload cifrati con chiavi sessione',
            'queue': 'Celery + Redis',
            'features': [
                'Push notifications iOS/Android',
                'WebSocket real-time',
                'Notifiche cifrate data-only',
                'Retry automatico',
                'Priorità messaggi',
                'Scheduling notifiche',
                'Analytics delivery'
            ],
            'dependencies': [
                'websockets',
                'firebase-admin',
                'celery',
                'redis',
                'cryptography'
            ],
            'performance': {
                'notifications_per_second': '1000+',
                'websocket_connections': '10000+',
                'delivery_rate': '99.5%',
                'memory_usage': '50-150MB',
            }
        }
    },
    'smtp_server': {
        'name': 'SMTP Server',
        'description': 'Server email interno per notifiche sistema',
        'port': 1025,
        'start_command': 'cd /Users/r.amoroso/Desktop/securevox-complete-cursor-pack/server && source venv/bin/activate && python -m smtpd -n -c DebuggingServer localhost:1025',
        'health_url': None,
        'log_file': '/var/log/securevox/smtp.log',
        'icon': 'fa-envelope',
        'color': '#9C27B0',
        'tech_specs': {
            'framework': 'Python SMTP Server',
            'language': 'Python 3.11+',
            'protocol': 'SMTP (Simple Mail Transfer Protocol)',
            'encryption': 'TLS/SSL support',
            'authentication': 'SASL, PLAIN, LOGIN',
            'queue': 'File-based queue',
            'features': [
                'Email interno sistema',
                'Notifiche admin',
                'Alert automatici',
                'Template email',
                'Attachments support',
                'Delivery tracking',
                'Spam filtering'
            ],
            'dependencies': [
                'smtplib (built-in)',
                'email (built-in)',
                'jinja2 (templates)',
                'python-dateutil'
            ],
            'performance': {
                'emails_per_minute': '100+',
                'max_attachment_size': '25MB',
                'queue_size': '1000 emails',
                'memory_usage': '20-50MB',
            }
        }
    },
    'redis_cache': {
        'name': 'Redis Cache Server',
        'description': 'Server cache in-memory e code task',
        'port': 6379,
        'start_command': 'redis-server --port 6379 --daemonize yes',
        'health_url': None,
        'log_file': '/var/log/redis/redis.log',
        'icon': 'fa-memory',
        'color': '#DC382D',
        'tech_specs': {
            'framework': 'Redis Server',
            'language': 'C (Redis core)',
            'data_structures': 'Strings, Hashes, Lists, Sets, Sorted Sets',
            'persistence': 'RDB snapshots + AOF logs',
            'clustering': 'Redis Cluster support',
            'replication': 'Master-Slave replication',
            'features': [
                'Cache applicazione',
                'Sessioni utente',
                'Code Celery',
                'Rate limiting',
                'Pub/Sub messaging',
                'Lua scripting',
                'Transazioni ACID'
            ],
            'dependencies': [
                'redis-server',
                'redis-cli',
                'redis-sentinel (HA)'
            ],
            'performance': {
                'operations_per_second': '100K+',
                'latency': '< 1ms',
                'memory_efficiency': '95%+',
                'max_memory': '8GB (configurable)',
            }
        }
    },
    'database': {
        'name': 'Database Server',
        'description': 'Database principale per persistenza dati',
        'port': 5432,
        'start_command': 'pg_ctl start -D /usr/local/var/postgres',
        'health_url': None,
        'log_file': '/usr/local/var/log/postgres.log',
        'icon': 'fa-database',
        'color': '#336791',
        'tech_specs': {
            'framework': 'PostgreSQL 16 / SQLite 3',
            'language': 'C (PostgreSQL core)',
            'acid_compliance': 'Full ACID compliance',
            'indexing': 'B-tree, Hash, GiST, SP-GiST, GIN, BRIN',
            'replication': 'Streaming replication',
            'backup': 'pg_dump, WAL archiving',
            'features': [
                'Transazioni ACID',
                'Constraint checking',
                'Foreign keys',
                'Triggers e stored procedures',
                'Full-text search',
                'JSON/JSONB support',
                'Encryption at rest'
            ],
            'dependencies': [
                'libpq (client library)',
                'psycopg2 (Python driver)',
                'pg_stat_statements'
            ],
            'performance': {
                'max_connections': '200+',
                'query_performance': '< 10ms avg',
                'storage_capacity': '1TB+',
                'backup_frequency': 'Daily automated',
            }
        }
    }
}


@user_passes_test(is_superuser)
def get_servers_status(request):
    """API per ottenere lo stato di tutti i server"""
    servers_status = {}
    
    for service_id, config in SERVICES_CONFIG.items():
        status = get_service_status(service_id, config)
        servers_status[service_id] = {
            **config,
            'status': status['status'],
            'pid': status['pid'],
            'uptime': status['uptime'],
            'memory_usage': status['memory_usage'],
            'cpu_usage': status['cpu_usage'],
            'last_check': status['last_check'],
        }
    
    return JsonResponse({
        'servers': servers_status,
        'system_load': get_system_load(),
        'timestamp': time.time(),
    })


@csrf_exempt
@require_http_methods(["POST"])
@user_passes_test(is_superuser)
def control_server(request, service_id):
    """API per controllare un server (start/stop/restart)"""
    if service_id not in SERVICES_CONFIG:
        return JsonResponse({'error': 'Servizio non trovato'}, status=404)
    
    try:
        data = json.loads(request.body)
        action = data.get('action')
        
        if action not in ['start', 'stop', 'restart']:
            return JsonResponse({'error': 'Azione non valida'}, status=400)
        
        config = SERVICES_CONFIG[service_id]
        result = execute_server_action(service_id, action, config)
        
        # Log dell'azione
        logger.info(f"Admin {request.user.username} executed {action} on {service_id}")
        
        return JsonResponse(result)
        
    except json.JSONDecodeError:
        return JsonResponse({'error': 'JSON non valido'}, status=400)
    except Exception as e:
        logger.error(f"Error controlling server {service_id}: {e}")
        return JsonResponse({'error': str(e)}, status=500)


def get_service_status(service_id, config):
    """Ottiene lo stato dettagliato di un servizio"""
    port = config['port']
    
    # Verifica se la porta è in uso
    pid = get_process_on_port(port)
    
    if pid:
        try:
            process = psutil.Process(pid)
            
            # Verifica che sia il processo giusto
            cmdline = ' '.join(process.cmdline())
            is_correct_process = any(keyword in cmdline.lower() for keyword in [
                service_id.replace('_', ''),
                config['name'].lower().replace(' ', ''),
                'manage.py' if 'django' in service_id else 'node',
                'securevox'
            ])
            
            if is_correct_process:
                return {
                    'status': 'running',
                    'pid': pid,
                    'uptime': time.time() - process.create_time(),
                    'memory_usage': process.memory_info().rss // (1024 * 1024),  # MB
                    'cpu_usage': process.cpu_percent(),
                    'last_check': time.time(),
                }
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    
    return {
        'status': 'stopped',
        'pid': None,
        'uptime': 0,
        'memory_usage': 0,
        'cpu_usage': 0,
        'last_check': time.time(),
    }


def get_process_on_port(port):
    """Trova il PID del processo che usa una porta"""
    try:
        for conn in psutil.net_connections():
            if conn.laddr.port == port and conn.status == 'LISTEN':
                return conn.pid
    except:
        pass
    return None


def execute_server_action(service_id, action, config):
    """Esegue un'azione su un server"""
    try:
        if action == 'stop':
            return stop_service(service_id, config)
        elif action == 'start':
            return start_service(service_id, config)
        elif action == 'restart':
            stop_result = stop_service(service_id, config)
            time.sleep(2)  # Attendi che si fermi completamente
            start_result = start_service(service_id, config)
            return {
                'success': start_result['success'],
                'message': f"Restart completato: {stop_result['message']} -> {start_result['message']}",
                'action': 'restart'
            }
    except Exception as e:
        return {
            'success': False,
            'message': f"Errore durante {action}: {str(e)}",
            'action': action
        }


def stop_service(service_id, config):
    """Ferma un servizio"""
    port = config['port']
    pid = get_process_on_port(port)
    
    if not pid:
        return {
            'success': True,
            'message': f"{config['name']} era già fermo",
            'action': 'stop'
        }
    
    try:
        # Prova prima SIGTERM (graceful shutdown)
        os.kill(pid, signal.SIGTERM)
        
        # Attendi fino a 10 secondi per shutdown graceful
        for _ in range(10):
            if not get_process_on_port(port):
                return {
                    'success': True,
                    'message': f"{config['name']} fermato correttamente",
                    'action': 'stop'
                }
            time.sleep(1)
        
        # Se non si è fermato, forza con SIGKILL
        try:
            os.kill(pid, signal.SIGKILL)
            return {
                'success': True,
                'message': f"{config['name']} fermato forzatamente",
                'action': 'stop'
            }
        except ProcessLookupError:
            return {
                'success': True,
                'message': f"{config['name']} fermato",
                'action': 'stop'
            }
            
    except ProcessLookupError:
        return {
            'success': True,
            'message': f"{config['name']} era già fermo",
            'action': 'stop'
        }
    except Exception as e:
        return {
            'success': False,
            'message': f"Errore fermando {config['name']}: {str(e)}",
            'action': 'stop'
        }


def start_service(service_id, config):
    """Avvia un servizio"""
    port = config['port']
    
    # Verifica se è già in esecuzione
    if get_process_on_port(port):
        return {
            'success': False,
            'message': f"{config['name']} è già in esecuzione sulla porta {port}",
            'action': 'start'
        }
    
    try:
        # Esegui il comando di avvio in background
        command = config['start_command']
        
        # Crea script temporaneo per eseguire il comando
        script_path = f"/tmp/start_{service_id}.sh"
        with open(script_path, 'w') as f:
            f.write("#!/bin/bash\n")
            f.write(f"{command}\n")
        
        os.chmod(script_path, 0o755)
        
        # Avvia il processo in background
        process = subprocess.Popen(
            [script_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            preexec_fn=os.setsid  # Crea un nuovo process group
        )
        
        # Attendi qualche secondo per verificare che si avvii
        time.sleep(3)
        
        # Verifica che sia effettivamente partito
        if get_process_on_port(port):
            # Pulisci script temporaneo
            try:
                os.remove(script_path)
            except:
                pass
                
            return {
                'success': True,
                'message': f"{config['name']} avviato correttamente sulla porta {port}",
                'action': 'start',
                'pid': get_process_on_port(port)
            }
        else:
            return {
                'success': False,
                'message': f"Errore: {config['name']} non si è avviato correttamente",
                'action': 'start'
            }
            
    except Exception as e:
        return {
            'success': False,
            'message': f"Errore avviando {config['name']}: {str(e)}",
            'action': 'start'
        }


def get_system_load():
    """Ottiene il carico di sistema generale"""
    try:
        return {
            'cpu_percent': psutil.cpu_percent(interval=1),
            'memory_percent': psutil.virtual_memory().percent,
            'disk_percent': psutil.disk_usage('/').percent,
            'load_avg': list(psutil.getloadavg()) if hasattr(psutil, 'getloadavg') else [0, 0, 0],
            'boot_time': psutil.boot_time(),
        }
    except:
        return {
            'cpu_percent': 0,
            'memory_percent': 0,
            'disk_percent': 0,
            'load_avg': [0, 0, 0],
            'boot_time': time.time(),
        }


@user_passes_test(is_superuser)
def get_service_logs(request, service_id):
    """API per ottenere i log di un servizio"""
    if service_id not in SERVICES_CONFIG:
        return JsonResponse({'error': 'Servizio non trovato'}, status=404)
    
    config = SERVICES_CONFIG[service_id]
    log_file = config.get('log_file')
    
    try:
        lines = int(request.GET.get('lines', 50))
        
        if log_file and os.path.exists(log_file):
            # Leggi le ultime N righe del log
            with open(log_file, 'r') as f:
                log_lines = f.readlines()[-lines:]
        else:
            # Fallback: usa journalctl o ps per ottenere info
            log_lines = get_service_output(service_id, config, lines)
        
        return JsonResponse({
            'logs': [line.strip() for line in log_lines],
            'service': config['name'],
            'timestamp': time.time(),
        })
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


def get_service_output(service_id, config, lines=50):
    """Ottiene output/log di un servizio"""
    try:
        port = config['port']
        pid = get_process_on_port(port)
        
        if pid:
            # Prova a ottenere info dal processo
            process = psutil.Process(pid)
            return [
                f"[INFO] Servizio {config['name']} in esecuzione",
                f"[INFO] PID: {pid}",
                f"[INFO] Porta: {port}",
                f"[INFO] Comando: {' '.join(process.cmdline())}",
                f"[INFO] Avviato: {time.ctime(process.create_time())}",
                f"[INFO] CPU: {process.cpu_percent()}%",
                f"[INFO] RAM: {process.memory_info().rss // (1024*1024)} MB",
            ]
        else:
            return [
                f"[WARNING] Servizio {config['name']} non in esecuzione",
                f"[INFO] Porta {port} libera",
            ]
    except Exception as e:
        return [f"[ERROR] Errore ottenendo info servizio: {str(e)}"]


@csrf_exempt
@require_http_methods(["POST"])
@user_passes_test(is_superuser)
def bulk_server_action(request):
    """API per azioni bulk sui server"""
    try:
        data = json.loads(request.body)
        action = data.get('action')
        service_ids = data.get('service_ids', [])
        
        if action not in ['start_all', 'stop_all', 'restart_all']:
            return JsonResponse({'error': 'Azione non valida'}, status=400)
        
        results = {}
        
        if action == 'stop_all':
            # Ferma tutti i servizi in ordine inverso
            for service_id in reversed(service_ids):
                if service_id in SERVICES_CONFIG:
                    result = execute_server_action(service_id, 'stop', SERVICES_CONFIG[service_id])
                    results[service_id] = result
                    time.sleep(1)  # Pausa tra stop
        
        elif action == 'start_all':
            # Avvia tutti i servizi in ordine
            for service_id in service_ids:
                if service_id in SERVICES_CONFIG:
                    result = execute_server_action(service_id, 'start', SERVICES_CONFIG[service_id])
                    results[service_id] = result
                    time.sleep(2)  # Pausa tra start per evitare conflitti
        
        elif action == 'restart_all':
            # Prima ferma tutti
            for service_id in reversed(service_ids):
                if service_id in SERVICES_CONFIG:
                    stop_result = execute_server_action(service_id, 'stop', SERVICES_CONFIG[service_id])
                    results[f"{service_id}_stop"] = stop_result
                    time.sleep(1)
            
            # Poi avvia tutti
            time.sleep(3)  # Pausa maggiore prima del restart
            for service_id in service_ids:
                if service_id in SERVICES_CONFIG:
                    start_result = execute_server_action(service_id, 'start', SERVICES_CONFIG[service_id])
                    results[f"{service_id}_start"] = start_result
                    time.sleep(2)
        
        # Conta successi
        successful_actions = sum(1 for result in results.values() if result.get('success'))
        total_actions = len(results)
        
        return JsonResponse({
            'success': successful_actions > 0,
            'message': f"Azione completata: {successful_actions}/{total_actions} operazioni riuscite",
            'results': results,
            'action': action,
        })
        
    except json.JSONDecodeError:
        return JsonResponse({'error': 'JSON non valido'}, status=400)
    except Exception as e:
        logger.error(f"Error in bulk server action: {e}")
        return JsonResponse({'error': str(e)}, status=500)


def get_server_performance(request, service_id):
    """API per ottenere performance di un servizio"""
    if not request.user.is_superuser:
        return JsonResponse({'error': 'Accesso negato'}, status=403)
    
    if service_id not in SERVICES_CONFIG:
        return JsonResponse({'error': 'Servizio non trovato'}, status=404)
    
    config = SERVICES_CONFIG[service_id]
    port = config['port']
    pid = get_process_on_port(port)
    
    if not pid:
        return JsonResponse({
            'service': config['name'],
            'status': 'stopped',
            'performance': None,
        })
    
    try:
        process = psutil.Process(pid)
        
        # Metriche dettagliate
        memory_info = process.memory_info()
        cpu_times = process.cpu_times()
        
        performance = {
            'cpu_percent': process.cpu_percent(),
            'memory_rss_mb': memory_info.rss // (1024 * 1024),
            'memory_vms_mb': memory_info.vms // (1024 * 1024),
            'memory_percent': process.memory_percent(),
            'num_threads': process.num_threads(),
            'num_fds': process.num_fds() if hasattr(process, 'num_fds') else 0,
            'create_time': process.create_time(),
            'uptime_seconds': time.time() - process.create_time(),
            'cpu_times': {
                'user': cpu_times.user,
                'system': cpu_times.system,
            },
            'status': process.status(),
            'cmdline': ' '.join(process.cmdline()),
        }
        
        # Statistiche rete per la porta
        network_stats = get_port_network_stats(port)
        
        return JsonResponse({
            'service': config['name'],
            'status': 'running',
            'performance': performance,
            'network': network_stats,
            'timestamp': time.time(),
        })
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


def get_port_network_stats(port):
    """Ottiene statistiche di rete per una porta"""
    try:
        # Conta connessioni per porta
        connections = []
        for conn in psutil.net_connections():
            if conn.laddr.port == port:
                connections.append({
                    'remote_addr': f"{conn.raddr.ip}:{conn.raddr.port}" if conn.raddr else "N/A",
                    'status': conn.status,
                    'type': conn.type.name if hasattr(conn.type, 'name') else str(conn.type),
                })
        
        return {
            'active_connections': len(connections),
            'connections': connections[:10],  # Prime 10 connessioni
        }
    except:
        return {
            'active_connections': 0,
            'connections': [],
        }


# Funzioni helper per comandi specifici
def kill_process_on_port(port):
    """Uccide il processo su una porta specifica"""
    try:
        result = subprocess.run(
            f"lsof -ti:{port} | xargs kill -9",
            shell=True,
            capture_output=True,
            text=True
        )
        return result.returncode == 0
    except:
        return False


def check_port_available(port):
    """Verifica se una porta è disponibile"""
    return get_process_on_port(port) is None


def get_service_health_detailed(service_id, config):
    """Controllo salute dettagliato di un servizio"""
    health_data = {
        'service_id': service_id,
        'name': config['name'],
        'status': 'unknown',
        'response_time': None,
        'last_error': None,
    }
    
    # Verifica porta
    if not get_process_on_port(config['port']):
        health_data['status'] = 'stopped'
        return health_data
    
    # Verifica health endpoint se disponibile
    health_url = config.get('health_url')
    if health_url:
        try:
            import requests
            start_time = time.time()
            response = requests.get(health_url, timeout=5)
            response_time = (time.time() - start_time) * 1000  # ms
            
            if response.status_code == 200:
                health_data['status'] = 'healthy'
                health_data['response_time'] = round(response_time, 2)
            else:
                health_data['status'] = 'unhealthy'
                health_data['last_error'] = f"HTTP {response.status_code}"
                
        except requests.exceptions.Timeout:
            health_data['status'] = 'timeout'
            health_data['last_error'] = "Timeout after 5s"
        except Exception as e:
            health_data['status'] = 'error'
            health_data['last_error'] = str(e)
    else:
        # Se non ha health endpoint, considera healthy se il processo è attivo
        health_data['status'] = 'running'
    
    return health_data
