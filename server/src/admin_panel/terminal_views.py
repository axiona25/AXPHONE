import os
import subprocess
import json
import pty
import select
import termios
import struct
import fcntl
import threading
import time
from django.http import JsonResponse, StreamingHttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.contrib.auth.decorators import user_passes_test
from django.utils.decorators import method_decorator
from django.views import View
import logging

logger = logging.getLogger(__name__)


def is_superuser(user):
    """Verifica che l'utente sia superuser"""
    return user.is_authenticated and user.is_superuser


# Dizionario per mantenere le sessioni terminale attive
TERMINAL_SESSIONS = {}


class TerminalSession:
    """Classe per gestire una sessione terminale"""
    
    def __init__(self, user_id):
        self.user_id = user_id
        self.master_fd = None
        self.slave_fd = None
        self.process = None
        self.is_active = False
        self.created_at = time.time()
        self.last_activity = time.time()
        
        # Percorso base SecureVOX
        self.base_path = '/Users/r.amoroso/Desktop/securevox-complete-cursor-pack'
        
    def start(self):
        """Avvia la sessione terminale"""
        try:
            # Crea pseudo-terminal
            self.master_fd, self.slave_fd = pty.openpty()
            
            # Avvia bash con percorso SecureVOX
            env = os.environ.copy()
            env['PS1'] = '\\[\\033[01;32m\\]securevox@\\h\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ '
            env['TERM'] = 'xterm-256color'
            
            self.process = subprocess.Popen(
                ['/bin/bash', '--login'],
                stdin=self.slave_fd,
                stdout=self.slave_fd,
                stderr=self.slave_fd,
                env=env,
                cwd=self.base_path,
                preexec_fn=os.setsid
            )
            
            # Configura il terminale
            self._setup_terminal()
            
            # Invia comando iniziale per impostare il percorso
            initial_commands = [
                f'cd {self.base_path}',
                'echo "🛡️ SecureVOX Terminal - Pronto per i comandi"',
                'echo "📁 Percorso base: $(pwd)"',
                'echo "🔧 Comandi utili:"',
                'echo "  • ls -la                    # Lista file"',
                'echo "  • cd server                 # Vai al server Django"',
                'echo "  • cd call-server            # Vai al call server"',
                'echo "  • cd mobile/securevox_app   # Vai all\'app mobile"',
                'echo "  • python manage.py --help   # Comandi Django"',
                'echo "  • docker ps                 # Container attivi"',
                'echo ""'
            ]
            
            for cmd in initial_commands:
                self.write_to_terminal(cmd + '\n')
                time.sleep(0.1)
            
            self.is_active = True
            logger.info(f"Terminal session started for user {self.user_id}")
            
        except Exception as e:
            logger.error(f"Error starting terminal session: {e}")
            self.cleanup()
            raise
    
    def _setup_terminal(self):
        """Configura le impostazioni del terminale"""
        try:
            # Imposta dimensioni terminale
            winsize = struct.pack('HHHH', 24, 80, 0, 0)  # rows, cols, xpixel, ypixel
            fcntl.ioctl(self.slave_fd, termios.TIOCSWINSZ, winsize)
            
            # Configura attributi terminale
            attrs = termios.tcgetattr(self.slave_fd)
            attrs[3] = attrs[3] | termios.ECHO  # Abilita echo
            termios.tcsetattr(self.slave_fd, termios.TCSANOW, attrs)
            
        except Exception as e:
            logger.warning(f"Could not setup terminal attributes: {e}")
    
    def write_to_terminal(self, data):
        """Scrive dati al terminale"""
        if self.master_fd and self.is_active:
            try:
                os.write(self.master_fd, data.encode('utf-8'))
                self.last_activity = time.time()
            except Exception as e:
                logger.error(f"Error writing to terminal: {e}")
    
    def read_from_terminal(self, timeout=0.1):
        """Legge dati dal terminale"""
        if not self.master_fd or not self.is_active:
            return b''
        
        try:
            ready, _, _ = select.select([self.master_fd], [], [], timeout)
            if ready:
                data = os.read(self.master_fd, 4096)
                self.last_activity = time.time()
                return data
        except Exception as e:
            logger.error(f"Error reading from terminal: {e}")
        
        return b''
    
    def resize_terminal(self, rows, cols):
        """Ridimensiona il terminale"""
        if self.slave_fd:
            try:
                winsize = struct.pack('HHHH', rows, cols, 0, 0)
                fcntl.ioctl(self.slave_fd, termios.TIOCSWINSZ, winsize)
            except Exception as e:
                logger.error(f"Error resizing terminal: {e}")
    
    def cleanup(self):
        """Pulisce la sessione terminale"""
        self.is_active = False
        
        if self.process:
            try:
                os.killpg(os.getpgid(self.process.pid), 9)
            except:
                pass
        
        if self.master_fd:
            try:
                os.close(self.master_fd)
            except:
                pass
        
        if self.slave_fd:
            try:
                os.close(self.slave_fd)
            except:
                pass
        
        logger.info(f"Terminal session cleaned up for user {self.user_id}")


@user_passes_test(is_superuser)
def get_terminal_session(request):
    """API per ottenere o creare una sessione terminale"""
    user_id = request.user.id
    
    # Pulisci sessioni vecchie (più di 1 ora di inattività)
    cleanup_old_sessions()
    
    # Verifica se esiste già una sessione attiva
    if user_id in TERMINAL_SESSIONS:
        session = TERMINAL_SESSIONS[user_id]
        if session.is_active:
            return JsonResponse({
                'session_id': user_id,
                'status': 'active',
                'created_at': session.created_at,
                'last_activity': session.last_activity,
            })
        else:
            # Sessione non attiva, rimuovila
            del TERMINAL_SESSIONS[user_id]
    
    # Crea nuova sessione
    try:
        session = TerminalSession(user_id)
        session.start()
        TERMINAL_SESSIONS[user_id] = session
        
        return JsonResponse({
            'session_id': user_id,
            'status': 'created',
            'created_at': session.created_at,
            'base_path': session.base_path,
        })
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["POST"])
@user_passes_test(is_superuser)
def terminal_input(request):
    """API per inviare input al terminale"""
    user_id = request.user.id
    
    if user_id not in TERMINAL_SESSIONS:
        return JsonResponse({'error': 'Sessione terminale non trovata'}, status=404)
    
    try:
        data = json.loads(request.body)
        input_data = data.get('input', '')
        
        session = TERMINAL_SESSIONS[user_id]
        session.write_to_terminal(input_data)
        
        return JsonResponse({'success': True})
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@user_passes_test(is_superuser)
def terminal_output(request):
    """API per ricevere output dal terminale (streaming)"""
    user_id = request.user.id
    
    if user_id not in TERMINAL_SESSIONS:
        return JsonResponse({'error': 'Sessione terminale non trovata'}, status=404)
    
    session = TERMINAL_SESSIONS[user_id]
    
    def generate_output():
        """Generatore per output streaming"""
        while session.is_active:
            try:
                output = session.read_from_terminal(timeout=0.5)
                if output:
                    # Converti in formato JSON per il frontend
                    yield f"data: {json.dumps({'output': output.decode('utf-8', errors='replace')})}\n\n"
                else:
                    # Heartbeat per mantenere la connessione
                    yield f"data: {json.dumps({'heartbeat': True})}\n\n"
                
                time.sleep(0.1)
                
            except Exception as e:
                logger.error(f"Error in terminal output stream: {e}")
                break
    
    response = StreamingHttpResponse(
        generate_output(),
        content_type='text/event-stream'
    )
    response['Cache-Control'] = 'no-cache'
    response['Connection'] = 'keep-alive'
    response['Access-Control-Allow-Origin'] = '*'
    
    return response


@csrf_exempt
@require_http_methods(["POST"])
@user_passes_test(is_superuser)
def terminal_resize(request):
    """API per ridimensionare il terminale"""
    user_id = request.user.id
    
    if user_id not in TERMINAL_SESSIONS:
        return JsonResponse({'error': 'Sessione terminale non trovata'}, status=404)
    
    try:
        data = json.loads(request.body)
        rows = int(data.get('rows', 24))
        cols = int(data.get('cols', 80))
        
        session = TERMINAL_SESSIONS[user_id]
        session.resize_terminal(rows, cols)
        
        return JsonResponse({'success': True})
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["POST"])
@user_passes_test(is_superuser)
def terminal_close(request):
    """API per chiudere una sessione terminale"""
    user_id = request.user.id
    
    if user_id in TERMINAL_SESSIONS:
        session = TERMINAL_SESSIONS[user_id]
        session.cleanup()
        del TERMINAL_SESSIONS[user_id]
        
        return JsonResponse({'success': True, 'message': 'Sessione terminale chiusa'})
    
    return JsonResponse({'error': 'Sessione non trovata'}, status=404)


@user_passes_test(is_superuser)
def execute_quick_command(request):
    """API per eseguire comandi rapidi predefiniti"""
    if request.method != 'POST':
        return JsonResponse({'error': 'Metodo non consentito'}, status=405)
    
    try:
        data = json.loads(request.body)
        command_id = data.get('command_id')
        
        # Comandi predefiniti sicuri
        quick_commands = {
            'server_status': 'cd server && python manage.py check',
            'migrate': 'cd server && python manage.py migrate',
            'collectstatic': 'cd server && python manage.py collectstatic --noinput',
            'create_superuser': 'cd server && python manage.py createsuperuser',
            'django_shell': 'cd server && python manage.py shell',
            'call_server_status': 'cd call-server && npm run status',
            'install_deps': 'cd server && pip install -r requirements.txt',
            'flutter_clean': 'cd mobile/securevox_app && flutter clean && flutter pub get',
            'docker_status': 'docker ps',
            'system_info': 'uname -a && free -h && df -h',
            'log_tail': 'tail -f /var/log/securevox/django.log',
        }
        
        if command_id not in quick_commands:
            return JsonResponse({'error': 'Comando non riconosciuto'}, status=400)
        
        command = quick_commands[command_id]
        
        # Esegui comando in modo sicuro
        result = subprocess.run(
            command,
            shell=True,
            cwd='/Users/r.amoroso/Desktop/securevox-complete-cursor-pack',
            capture_output=True,
            text=True,
            timeout=30  # Timeout di 30 secondi
        )
        
        return JsonResponse({
            'success': result.returncode == 0,
            'command': command,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'return_code': result.returncode,
        })
        
    except subprocess.TimeoutExpired:
        return JsonResponse({'error': 'Comando timeout (>30s)'}, status=408)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


def cleanup_old_sessions():
    """Pulisce le sessioni terminale vecchie"""
    current_time = time.time()
    to_remove = []
    
    for user_id, session in TERMINAL_SESSIONS.items():
        # Rimuovi sessioni inattive da più di 1 ora
        if current_time - session.last_activity > 3600:
            session.cleanup()
            to_remove.append(user_id)
    
    for user_id in to_remove:
        del TERMINAL_SESSIONS[user_id]
        logger.info(f"Removed inactive terminal session for user {user_id}")


@user_passes_test(is_superuser)
def get_terminal_commands(request):
    """API per ottenere i comandi rapidi disponibili"""
    commands = {
        'server_management': {
            'title': 'Gestione Server',
            'commands': [
                {
                    'id': 'server_status',
                    'name': 'Verifica Stato Django',
                    'description': 'Controlla configurazione e stato del server Django',
                    'icon': 'fa-server',
                    'estimated_time': '5s'
                },
                {
                    'id': 'migrate',
                    'name': 'Applica Migrazioni',
                    'description': 'Applica migrazioni database Django',
                    'icon': 'fa-database',
                    'estimated_time': '10s'
                },
                {
                    'id': 'collectstatic',
                    'name': 'Collect Static Files',
                    'description': 'Raccoglie file statici per produzione',
                    'icon': 'fa-folder',
                    'estimated_time': '15s'
                }
            ]
        },
        'development': {
            'title': 'Sviluppo',
            'commands': [
                {
                    'id': 'install_deps',
                    'name': 'Installa Dipendenze',
                    'description': 'Installa dipendenze Python dal requirements.txt',
                    'icon': 'fa-download',
                    'estimated_time': '60s'
                },
                {
                    'id': 'django_shell',
                    'name': 'Django Shell',
                    'description': 'Apre shell interattiva Django',
                    'icon': 'fa-terminal',
                    'estimated_time': 'Interactive'
                },
                {
                    'id': 'flutter_clean',
                    'name': 'Flutter Clean & Pub Get',
                    'description': 'Pulisce e aggiorna dipendenze Flutter',
                    'icon': 'fa-mobile-alt',
                    'estimated_time': '30s'
                }
            ]
        },
        'system': {
            'title': 'Sistema',
            'commands': [
                {
                    'id': 'system_info',
                    'name': 'Info Sistema',
                    'description': 'Mostra informazioni sistema (OS, RAM, Disk)',
                    'icon': 'fa-info-circle',
                    'estimated_time': '3s'
                },
                {
                    'id': 'docker_status',
                    'name': 'Docker Status',
                    'description': 'Mostra container Docker attivi',
                    'icon': 'fa-docker',
                    'estimated_time': '5s'
                },
                {
                    'id': 'log_tail',
                    'name': 'Tail Log Django',
                    'description': 'Mostra log Django in tempo reale',
                    'icon': 'fa-file-alt',
                    'estimated_time': 'Continuous'
                }
            ]
        },
        'user_management': {
            'title': 'Gestione Utenti',
            'commands': [
                {
                    'id': 'create_superuser',
                    'name': 'Crea Superuser',
                    'description': 'Crea nuovo utente amministratore',
                    'icon': 'fa-user-shield',
                    'estimated_time': 'Interactive'
                }
            ]
        }
    }
    
    return JsonResponse({'commands': commands})


@user_passes_test(is_superuser)
def get_system_info(request):
    """API per informazioni sistema dettagliate"""
    try:
        # Informazioni OS
        import platform
        import psutil
        
        # Info sistema
        system_info = {
            'os': {
                'system': platform.system(),
                'release': platform.release(),
                'version': platform.version(),
                'machine': platform.machine(),
                'processor': platform.processor(),
            },
            'python': {
                'version': platform.python_version(),
                'implementation': platform.python_implementation(),
                'compiler': platform.python_compiler(),
            },
            'hardware': {
                'cpu_count': psutil.cpu_count(),
                'cpu_freq': psutil.cpu_freq().current if psutil.cpu_freq() else 'N/A',
                'memory_total': psutil.virtual_memory().total // (1024**3),  # GB
                'disk_total': psutil.disk_usage('/').total // (1024**3),     # GB
            },
            'network': {
                'hostname': platform.node(),
                'interfaces': list(psutil.net_if_addrs().keys()),
            }
        }
        
        # Informazioni SecureVOX
        securevox_info = {
            'base_path': '/Users/r.amoroso/Desktop/securevox-complete-cursor-pack',
            'components': [
                'Django API Server (Python)',
                'Call Server (Node.js)',
                'Notification Server (Python)',
                'Mobile App (Flutter)',
                'Admin Dashboard (Web)',
                'SMTP Server (Python)',
                'Redis Cache',
                'Database (SQLite/PostgreSQL)'
            ],
            'versions': {
                'django': '4.2.16',
                'drf': '3.15.2',
                'node': get_node_version(),
                'flutter': get_flutter_version(),
            }
        }
        
        return JsonResponse({
            'system': system_info,
            'securevox': securevox_info,
            'timestamp': time.time(),
        })
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


def get_node_version():
    """Ottiene versione Node.js"""
    try:
        result = subprocess.run(['node', '--version'], capture_output=True, text=True, timeout=5)
        return result.stdout.strip() if result.returncode == 0 else 'N/A'
    except:
        return 'N/A'


def get_flutter_version():
    """Ottiene versione Flutter"""
    try:
        result = subprocess.run(['flutter', '--version'], capture_output=True, text=True, timeout=10)
        lines = result.stdout.split('\n')
        for line in lines:
            if 'Flutter' in line and 'channel' in line:
                return line.strip()
        return 'N/A'
    except:
        return 'N/A'


# Cleanup automatico delle sessioni quando il server si riavvia
def cleanup_all_sessions():
    """Pulisce tutte le sessioni terminale"""
    for user_id, session in list(TERMINAL_SESSIONS.items()):
        session.cleanup()
    TERMINAL_SESSIONS.clear()
    logger.info("All terminal sessions cleaned up")


# Registra cleanup all'uscita
import atexit
atexit.register(cleanup_all_sessions)
