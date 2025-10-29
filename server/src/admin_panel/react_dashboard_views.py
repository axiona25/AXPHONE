"""
Viste per servire la dashboard React real-time
"""
import os
from django.http import HttpResponse, JsonResponse
from django.conf import settings
from django.shortcuts import render
from django.contrib.auth.decorators import user_passes_test
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from django.views import View
import json
import logging

logger = logging.getLogger('securevox')

def is_admin_user(user):
    """Verifica che l'utente sia un amministratore"""
    return user.is_authenticated and (user.is_staff or user.is_superuser)

def react_dashboard_view(request):
    """Serve la dashboard React real-time"""
    try:
        # Path alla dashboard React buildata
        dashboard_path = os.path.join(settings.BASE_DIR.parent, 'admin', 'build', 'index.html')
        
        if os.path.exists(dashboard_path):
            with open(dashboard_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Sostituisci le variabili d'ambiente
            content = content.replace(
                'process.env.REACT_APP_API_URL',
                f'"{request.build_absolute_uri("/admin/api")}"'
            )
            content = content.replace(
                'process.env.REACT_APP_WS_URL',
                f'"{request.scheme}://{request.get_host().replace("8001", "8001")}/ws/admin"'
            )
            
            # Sostituisci i percorsi statici per usare /admin/static/
            content = content.replace('src="/static/', 'src="/admin/static/')
            content = content.replace('href="/static/', 'href="/admin/static/')
            content = content.replace('href="/manifest.json"', 'href="/admin/manifest.json"')
            
            return HttpResponse(content, content_type='text/html')
        else:
            # Fallback alla dashboard Django se React non è buildata
            return render(request, 'admin_panel/dashboard.html', {
                'error': 'Dashboard React non trovata. Esegui: cd admin && npm run build'
            })
            
    except Exception as e:
        logger.error(f"Errore nel caricamento dashboard React: {e}")
        return render(request, 'admin_panel/dashboard.html', {
            'error': f'Errore: {str(e)}'
        })

def react_static_files(request, file_path):
    """Serve i file statici della dashboard React"""
    try:
        # Path ai file statici della dashboard
        if file_path.startswith('../'):
            # Per manifest.json e altri file nella root
            file_path = file_path[3:]  # Rimuovi ../
            static_path = os.path.join(settings.BASE_DIR.parent, 'admin', 'build', file_path)
        else:
            static_path = os.path.join(settings.BASE_DIR.parent, 'admin', 'build', 'static', file_path)
        
        if os.path.exists(static_path):
            with open(static_path, 'rb') as f:
                content = f.read()
            
            # Determina il content type
            if file_path.endswith('.js'):
                content_type = 'application/javascript'
            elif file_path.endswith('.css'):
                content_type = 'text/css'
            elif file_path.endswith('.png'):
                content_type = 'image/png'
            elif file_path.endswith('.jpg') or file_path.endswith('.jpeg'):
                content_type = 'image/jpeg'
            elif file_path.endswith('.svg'):
                content_type = 'image/svg+xml'
            elif file_path.endswith('.woff2'):
                content_type = 'font/woff2'
            elif file_path.endswith('.woff'):
                content_type = 'font/woff'
            elif file_path.endswith('.ttf'):
                content_type = 'font/ttf'
            elif file_path.endswith('.json'):
                content_type = 'application/json'
            else:
                content_type = 'application/octet-stream'
            
            response = HttpResponse(content, content_type=content_type)
            
            # Cache headers per file statici
            if file_path.endswith(('.js', '.css', '.woff2', '.woff', '.ttf')):
                response['Cache-Control'] = 'public, max-age=31536000'  # 1 anno
            
            return response
        else:
            logger.warning(f"File statico non trovato: {static_path}")
            return HttpResponse("File not found", status=404)
            
    except Exception as e:
        logger.error(f"Errore nel caricamento file statico {file_path}: {e}")
        return HttpResponse("Error loading file", status=500)

@csrf_exempt
def api_login_view(request):
    """API endpoint per login della dashboard React"""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            username = data.get('username')
            password = data.get('password')
            
            from django.contrib.auth import authenticate, login
            
            user = authenticate(request, username=username, password=password)
            if user is not None and (user.is_staff or user.is_superuser):
                login(request, user)
                return JsonResponse({
                    'success': True,
                    'user': {
                        'id': user.id,
                        'username': user.username,
                        'email': user.email,
                        'first_name': user.first_name,
                        'last_name': user.last_name,
                        'is_staff': user.is_staff,
                        'is_superuser': user.is_superuser,
                        'last_login': user.last_login.isoformat() if user.last_login else None,
                    }
                })
            else:
                return JsonResponse({
                    'success': False,
                    'error': 'Credenziali non valide o permessi insufficienti'
                }, status=401)
                
        except json.JSONDecodeError:
            return JsonResponse({
                'success': False,
                'error': 'Dati JSON non validi'
            }, status=400)
        except Exception as e:
            return JsonResponse({
                'success': False,
                'error': str(e)
            }, status=500)
    
    return JsonResponse({'error': 'Metodo non consentito'}, status=405)

@user_passes_test(is_admin_user, login_url='/admin/login/')
def api_logout_view(request):
    """API endpoint per logout della dashboard React"""
    from django.contrib.auth import logout
    logout(request)
    return JsonResponse({'success': True})

@user_passes_test(is_admin_user, login_url='/admin/login/')
def api_current_user_view(request):
    """API endpoint per ottenere l'utente corrente"""
    user = request.user
    return JsonResponse({
        'id': user.id,
        'username': user.username,
        'email': user.email,
        'first_name': user.first_name,
        'last_name': user.last_name,
        'is_staff': user.is_staff,
        'is_superuser': user.is_superuser,
        'last_login': user.last_login.isoformat() if user.last_login else None,
    })
