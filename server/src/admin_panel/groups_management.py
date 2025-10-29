import json
import uuid
from django.http import JsonResponse
from django.contrib.auth.models import User
from django.contrib.auth.decorators import user_passes_test
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.db.models import Q, Count
from django.utils import timezone

from .models import AdminAction


def is_superuser(user):
    """Verifica che l'utente sia superuser"""
    return user.is_authenticated and user.is_superuser


# Mock model per gruppi (da sostituire con modello reale)
class UserGroup:
    """Classe mock per gruppi utenti"""
    
    # Storage in memoria per demo (in produzione usare database)
    _groups = {
        '1': {
            'id': '1',
            'name': 'Amministratori',
            'description': 'Gruppo degli amministratori di sistema con accesso completo',
            'color': '#F44336',
            'permissions': ['all'],
            'created_at': '2024-01-01T00:00:00Z',
            'created_by': 'admin',
            'is_active': True,
            'members': [],
        },
        '2': {
            'id': '2',
            'name': 'Sviluppatori',
            'description': 'Team di sviluppo con accesso a funzionalità avanzate',
            'color': '#2196F3',
            'permissions': ['chat', 'calls', 'files', 'devices'],
            'created_at': '2024-01-01T00:00:00Z',
            'created_by': 'admin',
            'is_active': True,
            'members': [],
        },
        '3': {
            'id': '3',
            'name': 'Utenti Standard',
            'description': 'Utenti normali con permessi base',
            'color': '#26A884',
            'permissions': ['chat', 'calls'],
            'created_at': '2024-01-01T00:00:00Z',
            'created_by': 'admin',
            'is_active': True,
            'members': [],
        },
        '4': {
            'id': '4',
            'name': 'Beta Tester',
            'description': 'Gruppo per test di nuove funzionalità',
            'color': '#FF9800',
            'permissions': ['chat', 'calls', 'beta_features'],
            'created_at': '2024-01-01T00:00:00Z',
            'created_by': 'admin',
            'is_active': True,
            'members': [],
        },
    }
    
    @classmethod
    def get_all(cls):
        return [group for group in cls._groups.values() if group['is_active']]
    
    @classmethod
    def get_by_id(cls, group_id):
        return cls._groups.get(str(group_id))
    
    @classmethod
    def create(cls, data):
        group_id = str(uuid.uuid4())
        group = {
            'id': group_id,
            'name': data['name'],
            'description': data.get('description', ''),
            'color': data.get('color', '#26A884'),
            'permissions': data.get('permissions', ['chat']),
            'created_at': timezone.now().isoformat(),
            'created_by': data.get('created_by', 'admin'),
            'is_active': True,
            'members': [],
        }
        cls._groups[group_id] = group
        return group
    
    @classmethod
    def update(cls, group_id, data):
        if str(group_id) in cls._groups:
            group = cls._groups[str(group_id)]
            group.update(data)
            return group
        return None
    
    @classmethod
    def delete(cls, group_id):
        if str(group_id) in cls._groups:
            cls._groups[str(group_id)]['is_active'] = False
            return True
        return False


@user_passes_test(is_superuser)
def get_groups_advanced(request):
    """API avanzata per gestione gruppi"""
    
    # Parametri query
    search = request.GET.get('search', '').strip()
    sort_by = request.GET.get('sort_by', 'name')
    sort_order = request.GET.get('sort_order', 'asc')
    
    # Ottieni tutti i gruppi
    groups = UserGroup.get_all()
    
    # Applica filtri
    if search:
        groups = [
            group for group in groups
            if search.lower() in group['name'].lower() or 
               search.lower() in group['description'].lower()
        ]
    
    # Calcola statistiche per ogni gruppo
    for group in groups:
        # Simula membri (in produzione verrebbe dal database)
        if group['name'] == 'Amministratori':
            group['members_count'] = User.objects.filter(is_superuser=True).count()
        elif group['name'] == 'Sviluppatori':
            group['members_count'] = User.objects.filter(is_staff=True, is_superuser=False).count()
        else:
            group['members_count'] = User.objects.filter(is_staff=False).count()
        
        # Aggiungi statistiche attività
        group['activity_score'] = calculate_group_activity_score(group['id'])
        group['last_activity'] = get_group_last_activity(group['id'])
    
    # Ordinamento
    reverse = sort_order == 'desc'
    if sort_by == 'name':
        groups.sort(key=lambda x: x['name'], reverse=reverse)
    elif sort_by == 'members':
        groups.sort(key=lambda x: x['members_count'], reverse=reverse)
    elif sort_by == 'created_at':
        groups.sort(key=lambda x: x['created_at'], reverse=reverse)
    
    # Statistiche generali
    stats = {
        'total_groups': len(groups),
        'active_groups': len([g for g in groups if g['is_active']]),
        'total_members': sum(g['members_count'] for g in groups),
        'avg_members_per_group': sum(g['members_count'] for g in groups) / len(groups) if groups else 0,
    }
    
    return JsonResponse({
        'groups': groups,
        'statistics': stats,
        'available_permissions': get_available_permissions(),
    })


@csrf_exempt
@require_http_methods(["POST"])
@user_passes_test(is_superuser)
def create_group(request):
    """API per creare un nuovo gruppo"""
    try:
        data = json.loads(request.body)
        
        # Validazione
        name = data.get('name', '').strip()
        if not name:
            return JsonResponse({'error': 'Nome gruppo obbligatorio'}, status=400)
        
        # Verifica unicità nome
        existing_groups = UserGroup.get_all()
        if any(group['name'].lower() == name.lower() for group in existing_groups):
            return JsonResponse({'error': 'Nome gruppo già esistente'}, status=400)
        
        # Crea gruppo
        group_data = {
            'name': name,
            'description': data.get('description', ''),
            'color': data.get('color', '#26A884'),
            'permissions': data.get('permissions', ['chat']),
            'created_by': request.user.username,
        }
        
        group = UserGroup.create(group_data)
        
        # Log dell'azione
        AdminAction.objects.create(
            admin=request.user,
            action_type='group_create',
            details={
                'group_name': name,
                'permissions': group_data['permissions'],
            },
            ip_address=get_client_ip(request),
        )
        
        return JsonResponse({
            'success': True,
            'message': f'Gruppo "{name}" creato con successo',
            'group': group,
        })
        
    except json.JSONDecodeError:
        return JsonResponse({'error': 'JSON non valido'}, status=400)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["POST"])
@user_passes_test(is_superuser)
def update_group(request, group_id):
    """API per aggiornare un gruppo"""
    try:
        data = json.loads(request.body)
        
        group = UserGroup.get_by_id(group_id)
        if not group:
            return JsonResponse({'error': 'Gruppo non trovato'}, status=404)
        
        # Aggiorna campi
        update_data = {}
        if 'name' in data:
            update_data['name'] = data['name'].strip()
        if 'description' in data:
            update_data['description'] = data['description'].strip()
        if 'color' in data:
            update_data['color'] = data['color']
        if 'permissions' in data:
            update_data['permissions'] = data['permissions']
        
        updated_group = UserGroup.update(group_id, update_data)
        
        # Log dell'azione
        AdminAction.objects.create(
            admin=request.user,
            action_type='group_update',
            details={
                'group_id': group_id,
                'group_name': updated_group['name'],
                'changes': update_data,
            },
            ip_address=get_client_ip(request),
        )
        
        return JsonResponse({
            'success': True,
            'message': f'Gruppo "{updated_group["name"]}" aggiornato con successo',
            'group': updated_group,
        })
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["DELETE"])
@user_passes_test(is_superuser)
def delete_group(request, group_id):
    """API per eliminare un gruppo"""
    try:
        group = UserGroup.get_by_id(group_id)
        if not group:
            return JsonResponse({'error': 'Gruppo non trovato'}, status=404)
        
        group_name = group['name']
        
        # Non permettere eliminazione di gruppi di sistema
        if group_name in ['Amministratori', 'Sviluppatori']:
            return JsonResponse({'error': 'Non è possibile eliminare gruppi di sistema'}, status=400)
        
        UserGroup.delete(group_id)
        
        # Log dell'azione
        AdminAction.objects.create(
            admin=request.user,
            action_type='group_delete',
            details={
                'group_id': group_id,
                'group_name': group_name,
            },
            ip_address=get_client_ip(request),
        )
        
        return JsonResponse({
            'success': True,
            'message': f'Gruppo "{group_name}" eliminato con successo',
        })
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["POST"])
@user_passes_test(is_superuser)
def manage_group_members(request, group_id):
    """API per gestire membri di un gruppo"""
    try:
        data = json.loads(request.body)
        action = data.get('action')  # add, remove, set
        user_ids = data.get('user_ids', [])
        
        group = UserGroup.get_by_id(group_id)
        if not group:
            return JsonResponse({'error': 'Gruppo non trovato'}, status=404)
        
        # Verifica che gli utenti esistano
        users = User.objects.filter(id__in=user_ids)
        if users.count() != len(user_ids):
            return JsonResponse({'error': 'Alcuni utenti non esistono'}, status=400)
        
        results = {'success': 0, 'failed': 0, 'details': []}
        
        if action == 'add':
            # Aggiungi utenti al gruppo
            for user in users:
                # Simula aggiunta (in produzione: GroupMembership.objects.create)
                results['details'].append(f'Utente {user.username} aggiunto al gruppo')
                results['success'] += 1
        
        elif action == 'remove':
            # Rimuovi utenti dal gruppo
            for user in users:
                # Simula rimozione (in produzione: GroupMembership.objects.filter(...).delete)
                results['details'].append(f'Utente {user.username} rimosso dal gruppo')
                results['success'] += 1
        
        elif action == 'set':
            # Imposta esattamente questi utenti nel gruppo
            results['details'].append(f'Membri gruppo impostati: {len(user_ids)} utenti')
            results['success'] = len(user_ids)
        
        # Log dell'azione
        AdminAction.objects.create(
            admin=request.user,
            action_type='group_members_update',
            details={
                'group_id': group_id,
                'group_name': group['name'],
                'action': action,
                'user_count': len(user_ids),
            },
            ip_address=get_client_ip(request),
        )
        
        return JsonResponse({
            'success': True,
            'message': f"Azione '{action}' completata: {results['success']} operazioni riuscite",
            'results': results,
        })
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@user_passes_test(is_superuser)
def get_group_members(request, group_id):
    """API per ottenere membri di un gruppo"""
    try:
        group = UserGroup.get_by_id(group_id)
        if not group:
            return JsonResponse({'error': 'Gruppo non trovato'}, status=404)
        
        # Simula membri del gruppo basandosi sul tipo
        if group['name'] == 'Amministratori':
            members = User.objects.filter(is_superuser=True)
        elif group['name'] == 'Sviluppatori':
            members = User.objects.filter(is_staff=True, is_superuser=False)
        else:
            members = User.objects.filter(is_staff=False)[:10]  # Primi 10 per demo
        
        members_data = []
        for user in members:
            members_data.append({
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'full_name': f"{user.first_name} {user.last_name}".strip() or user.username,
                'is_active': user.is_active,
                'last_login': user.last_login.isoformat() if user.last_login else None,
                'date_joined': user.date_joined.isoformat(),
                'role_in_group': 'admin' if user.is_superuser else 'member',
            })
        
        return JsonResponse({
            'group': group,
            'members': members_data,
            'members_count': len(members_data),
        })
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@user_passes_test(is_superuser)
def get_available_users(request):
    """API per ottenere utenti disponibili per assegnazione gruppi"""
    group_id = request.GET.get('group_id')
    search = request.GET.get('search', '').strip()
    
    # Query base
    users = User.objects.all()
    
    # Filtro ricerca
    if search:
        users = users.filter(
            Q(username__icontains=search) |
            Q(email__icontains=search) |
            Q(first_name__icontains=search) |
            Q(last_name__icontains=search)
        )
    
    # Se specificato un gruppo, escludi membri attuali
    if group_id:
        group = UserGroup.get_by_id(group_id)
        if group:
            # In produzione: users = users.exclude(group_memberships__group_id=group_id)
            pass
    
    users_data = []
    for user in users[:50]:  # Limita a 50 per performance
        users_data.append({
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'full_name': f"{user.first_name} {user.last_name}".strip() or user.username,
            'is_active': user.is_active,
            'is_staff': user.is_staff,
            'avatar_url': getattr(user.profile, 'avatar_url', None) if hasattr(user, 'profile') else None,
        })
    
    return JsonResponse({
        'users': users_data,
        'total_count': User.objects.count(),
    })


def get_available_permissions():
    """Ottiene permessi disponibili per i gruppi"""
    return [
        {
            'id': 'chat',
            'name': 'Chat',
            'description': 'Accesso alle funzionalità di chat',
            'category': 'communication'
        },
        {
            'id': 'calls',
            'name': 'Chiamate',
            'description': 'Accesso a chiamate audio/video',
            'category': 'communication'
        },
        {
            'id': 'files',
            'name': 'Condivisione File',
            'description': 'Upload e download file',
            'category': 'files'
        },
        {
            'id': 'contacts',
            'name': 'Rubrica',
            'description': 'Accesso alla rubrica contatti',
            'category': 'contacts'
        },
        {
            'id': 'devices',
            'name': 'Gestione Dispositivi',
            'description': 'Registrazione e gestione dispositivi',
            'category': 'security'
        },
        {
            'id': 'admin',
            'name': 'Amministrazione',
            'description': 'Accesso pannello amministrativo',
            'category': 'admin'
        },
        {
            'id': 'beta_features',
            'name': 'Funzionalità Beta',
            'description': 'Accesso a funzionalità in fase di test',
            'category': 'development'
        },
        {
            'id': 'all',
            'name': 'Tutti i Permessi',
            'description': 'Accesso completo a tutte le funzionalità',
            'category': 'admin'
        }
    ]


def calculate_group_activity_score(group_id):
    """Calcola punteggio attività per un gruppo"""
    # Mock - in produzione calcolare basandosi su messaggi/chiamate dei membri
    import random
    return random.randint(60, 100)


def get_group_last_activity(group_id):
    """Ottiene ultima attività del gruppo"""
    # Mock - in produzione basarsi su ultima attività dei membri
    last_activity = timezone.now() - timedelta(hours=random.randint(1, 48))
    return last_activity.isoformat()


def get_client_ip(request):
    """Ottiene IP del client"""
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip


# Import necessari per le funzioni
import random
