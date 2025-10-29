import json
from django.http import JsonResponse
from django.contrib.auth.models import User
from django.contrib.auth.decorators import user_passes_test
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.db.models import Q, Count
from django.utils import timezone
from django.core.paginator import Paginator
from datetime import datetime, timedelta

from crypto.models import Device, Message
from .models import UserProfile, AdminAction


def is_superuser(user):
    """Verifica che l'utente sia superuser"""
    return user.is_authenticated and user.is_superuser


@user_passes_test(is_superuser)
def get_users_advanced(request):
    """API avanzata per gestione utenti con filtri e paginazione"""
    
    # Parametri query
    search = request.GET.get('search', '').strip()
    status = request.GET.get('status', 'all')  # all, active, blocked, online
    group_id = request.GET.get('group_id')
    device_type = request.GET.get('device_type')
    sort_by = request.GET.get('sort_by', 'date_joined')
    sort_order = request.GET.get('sort_order', 'desc')
    page = int(request.GET.get('page', 1))
    per_page = int(request.GET.get('per_page', 20))
    
    # Query base con ottimizzazioni
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
        recent = timezone.now() - timedelta(minutes=5)
        users = users.filter(last_login__gte=recent)
    elif status == 'staff':
        users = users.filter(is_staff=True)
    
    if group_id:
        users = users.filter(group_memberships__group_id=group_id, group_memberships__is_active=True)
    
    if device_type:
        users = users.filter(devices__device_type=device_type, devices__is_active=True).distinct()
    
    # Ordinamento
    sort_field = sort_by
    if sort_order == 'desc':
        sort_field = f'-{sort_field}'
    
    users = users.order_by(sort_field)
    
    # Conta totali per statistiche
    total_users = users.count()
    
    # Paginazione
    paginator = Paginator(users, per_page)
    page_obj = paginator.get_page(page)
    
    # Prepara dati utenti
    users_data = []
    for user in page_obj:
        # Calcola statistiche utente
        user_stats = calculate_user_stats(user)
        
        # Ottieni gruppi
        groups = [
            {
                'id': str(membership.group.id),
                'name': membership.group.name,
                'color': membership.group.color,
                'assigned_at': membership.assigned_at.isoformat(),
            }
            for membership in user.group_memberships.filter(is_active=True)
        ] if hasattr(user, 'group_memberships') else []
        
        # Ottieni dispositivi
        devices = [
            {
                'id': str(device.id),
                'name': device.device_name,
                'type': device.device_type,
                'is_active': device.is_active,
                'is_compromised': device.is_rooted or device.is_jailbroken or device.is_compromised,
                'last_seen': device.last_seen.isoformat() if device.last_seen else None,
            }
            for device in user.devices.all()
        ]
        
        users_data.append({
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'full_name': f"{user.first_name} {user.last_name}".strip() or user.username,
            'is_active': user.is_active,
            'is_staff': user.is_staff,
            'is_superuser': user.is_superuser,
            'date_joined': user.date_joined.isoformat(),
            'last_login': user.last_login.isoformat() if user.last_login else None,
            'avatar_url': getattr(user.profile, 'avatar_url', None) if hasattr(user, 'profile') else None,
            'phone_number': getattr(user.profile, 'phone_number', '') if hasattr(user, 'profile') else '',
            'groups': groups,
            'devices': devices,
            'statistics': user_stats,
            'security_status': get_user_security_status(user),
            'online_status': get_user_online_status(user),
        })
    
    # Statistiche generali
    stats = {
        'total_users': User.objects.count(),
        'active_users': User.objects.filter(is_active=True).count(),
        'blocked_users': User.objects.filter(is_active=False).count(),
        'staff_users': User.objects.filter(is_staff=True).count(),
        'online_users': User.objects.filter(
            last_login__gte=timezone.now() - timedelta(minutes=5)
        ).count(),
        'new_users_24h': User.objects.filter(
            date_joined__gte=timezone.now() - timedelta(hours=24)
        ).count(),
    }
    
    return JsonResponse({
        'users': users_data,
        'statistics': stats,
        'pagination': {
            'page': page_obj.number,
            'per_page': per_page,
            'total_pages': paginator.num_pages,
            'total_count': paginator.count,
            'has_next': page_obj.has_next(),
            'has_previous': page_obj.has_previous(),
        },
        'filters': {
            'search': search,
            'status': status,
            'group_id': group_id,
            'device_type': device_type,
            'sort_by': sort_by,
            'sort_order': sort_order,
        }
    })


@csrf_exempt
@require_http_methods(["POST"])
@user_passes_test(is_superuser)
def create_user(request):
    """API per creare un nuovo utente"""
    try:
        data = json.loads(request.body)
        
        # Validazione dati
        username = data.get('username', '').strip()
        email = data.get('email', '').strip()
        password = data.get('password', '')
        first_name = data.get('first_name', '').strip()
        last_name = data.get('last_name', '').strip()
        is_staff = data.get('is_staff', False)
        is_active = data.get('is_active', True)
        
        if not username or not email or not password:
            return JsonResponse({'error': 'Username, email e password sono obbligatori'}, status=400)
        
        # Verifica unicità
        if User.objects.filter(username=username).exists():
            return JsonResponse({'error': 'Username già esistente'}, status=400)
        
        if User.objects.filter(email=email).exists():
            return JsonResponse({'error': 'Email già esistente'}, status=400)
        
        # Crea utente
        user = User.objects.create_user(
            username=username,
            email=email,
            password=password,
            first_name=first_name,
            last_name=last_name,
            is_staff=is_staff,
            is_active=is_active
        )
        
        # Crea profilo se non esiste
        profile, created = UserProfile.objects.get_or_create(
            user=user,
            defaults={
                'phone_number': data.get('phone_number', ''),
                'bio': data.get('bio', ''),
            }
        )
        
        # Log dell'azione
        AdminAction.objects.create(
            admin=request.user,
            action_type='user_create',
            target_user=user,
            details={
                'username': username,
                'email': email,
                'is_staff': is_staff,
            },
            ip_address=get_client_ip(request),
        )
        
        return JsonResponse({
            'success': True,
            'message': f'Utente {username} creato con successo',
            'user_id': user.id,
        })
        
    except json.JSONDecodeError:
        return JsonResponse({'error': 'JSON non valido'}, status=400)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["POST"])
@user_passes_test(is_superuser)
def update_user(request, user_id):
    """API per aggiornare un utente"""
    try:
        user = User.objects.get(id=user_id)
        data = json.loads(request.body)
        
        # Aggiorna campi utente
        if 'username' in data:
            new_username = data['username'].strip()
            if new_username != user.username and User.objects.filter(username=new_username).exists():
                return JsonResponse({'error': 'Username già esistente'}, status=400)
            user.username = new_username
        
        if 'email' in data:
            new_email = data['email'].strip()
            if new_email != user.email and User.objects.filter(email=new_email).exists():
                return JsonResponse({'error': 'Email già esistente'}, status=400)
            user.email = new_email
        
        if 'first_name' in data:
            user.first_name = data['first_name'].strip()
        
        if 'last_name' in data:
            user.last_name = data['last_name'].strip()
        
        if 'is_active' in data:
            user.is_active = data['is_active']
        
        if 'is_staff' in data:
            user.is_staff = data['is_staff']
        
        # Non permettere di rimuovere superuser status a se stesso
        if 'is_superuser' in data and user.id != request.user.id:
            user.is_superuser = data['is_superuser']
        
        user.save()
        
        # Aggiorna profilo se esiste
        if hasattr(user, 'profile'):
            profile = user.profile
            if 'phone_number' in data:
                profile.phone_number = data['phone_number']
            if 'bio' in data:
                profile.bio = data['bio']
            profile.save()
        
        # Log dell'azione
        AdminAction.objects.create(
            admin=request.user,
            action_type='user_update',
            target_user=user,
            details=data,
            ip_address=get_client_ip(request),
        )
        
        return JsonResponse({
            'success': True,
            'message': f'Utente {user.username} aggiornato con successo',
        })
        
    except User.DoesNotExist:
        return JsonResponse({'error': 'Utente non trovato'}, status=404)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["POST"])
@user_passes_test(is_superuser)
def bulk_user_actions(request):
    """API per azioni bulk sugli utenti"""
    try:
        data = json.loads(request.body)
        action = data.get('action')
        user_ids = data.get('user_ids', [])
        
        if not user_ids:
            return JsonResponse({'error': 'Nessun utente selezionato'}, status=400)
        
        # Verifica che l'admin non possa fare azioni su se stesso
        if request.user.id in [int(uid) for uid in user_ids]:
            return JsonResponse({'error': 'Non puoi eseguire azioni bulk su te stesso'}, status=400)
        
        users = User.objects.filter(id__in=user_ids)
        results = {'success': 0, 'failed': 0, 'details': []}
        
        for user in users:
            try:
                if action == 'delete':
                    username = user.username
                    user.delete()
                    results['details'].append(f'Utente {username} eliminato')
                    results['success'] += 1
                    
                elif action == 'block':
                    user.is_active = False
                    user.save()
                    results['details'].append(f'Utente {user.username} bloccato')
                    results['success'] += 1
                    
                elif action == 'unblock':
                    user.is_active = True
                    user.save()
                    results['details'].append(f'Utente {user.username} sbloccato')
                    results['success'] += 1
                    
                elif action == 'make_staff':
                    user.is_staff = True
                    user.save()
                    results['details'].append(f'Utente {user.username} promosso a staff')
                    results['success'] += 1
                    
                elif action == 'remove_staff':
                    user.is_staff = False
                    user.save()
                    results['details'].append(f'Utente {user.username} rimosso da staff')
                    results['success'] += 1
                
                # Log dell'azione
                AdminAction.objects.create(
                    admin=request.user,
                    action_type=f'user_{action}',
                    target_user=user if action != 'delete' else None,
                    details={'bulk_action': True, 'action': action},
                    ip_address=get_client_ip(request),
                )
                
            except Exception as e:
                results['details'].append(f'Errore su {user.username}: {str(e)}')
                results['failed'] += 1
        
        return JsonResponse({
            'success': results['success'] > 0,
            'message': f"Azione completata: {results['success']} successi, {results['failed']} errori",
            'results': results,
        })
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["DELETE"])
@user_passes_test(is_superuser)
def delete_user(request, user_id):
    """API per eliminare un singolo utente"""
    try:
        user = User.objects.get(id=user_id)
        
        # Non permettere eliminazione di se stesso
        if user.id == request.user.id:
            return JsonResponse({'error': 'Non puoi eliminare te stesso'}, status=400)
        
        username = user.username
        user.delete()
        
        # Log dell'azione
        AdminAction.objects.create(
            admin=request.user,
            action_type='user_delete',
            details={'deleted_username': username},
            ip_address=get_client_ip(request),
        )
        
        return JsonResponse({
            'success': True,
            'message': f'Utente {username} eliminato con successo',
        })
        
    except User.DoesNotExist:
        return JsonResponse({'error': 'Utente non trovato'}, status=404)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@user_passes_test(is_superuser)
def get_user_details(request, user_id):
    """API per ottenere dettagli completi di un utente"""
    try:
        user = User.objects.select_related('profile').prefetch_related(
            'devices', 'group_memberships__group'
        ).get(id=user_id)
        
        # Statistiche dettagliate
        stats = calculate_user_stats(user)
        
        # Attività recente
        recent_activity = get_user_recent_activity(user)
        
        # Dispositivi dettagliati
        devices = [
            {
                'id': str(device.id),
                'name': device.device_name,
                'type': device.device_type,
                'is_active': device.is_active,
                'is_rooted': device.is_rooted,
                'is_jailbroken': device.is_jailbroken,
                'is_compromised': device.is_compromised,
                'last_seen': device.last_seen.isoformat() if device.last_seen else None,
                'created_at': device.created_at.isoformat(),
                'app_version': getattr(device, 'app_version', 'N/A'),
                'os_version': getattr(device, 'os_version', 'N/A'),
            }
            for device in user.devices.all()
        ]
        
        return JsonResponse({
            'user': {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'is_active': user.is_active,
                'is_staff': user.is_staff,
                'is_superuser': user.is_superuser,
                'date_joined': user.date_joined.isoformat(),
                'last_login': user.last_login.isoformat() if user.last_login else None,
                'phone_number': getattr(user.profile, 'phone_number', '') if hasattr(user, 'profile') else '',
                'bio': getattr(user.profile, 'bio', '') if hasattr(user, 'profile') else '',
            },
            'devices': devices,
            'statistics': stats,
            'recent_activity': recent_activity,
            'security_status': get_user_security_status(user),
        })
        
    except User.DoesNotExist:
        return JsonResponse({'error': 'Utente non trovato'}, status=404)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


# Helper functions
def calculate_user_stats(user):
    """Calcola statistiche dettagliate per un utente"""
    now = timezone.now()
    last_30d = now - timedelta(days=30)
    last_7d = now - timedelta(days=7)
    last_24h = now - timedelta(hours=24)
    
    # Messaggi inviati e ricevuti
    sent_messages = Message.objects.filter(sender__user=user)
    received_messages = Message.objects.filter(recipient__user=user)
    
    return {
        'messages': {
            'sent_total': sent_messages.count(),
            'sent_30d': sent_messages.filter(created_at__gte=last_30d).count(),
            'sent_7d': sent_messages.filter(created_at__gte=last_7d).count(),
            'sent_24h': sent_messages.filter(created_at__gte=last_24h).count(),
            'received_total': received_messages.count(),
            'received_30d': received_messages.filter(created_at__gte=last_30d).count(),
        },
        'devices': {
            'total': user.devices.count(),
            'active': user.devices.filter(is_active=True).count(),
            'compromised': user.devices.filter(
                Q(is_rooted=True) | Q(is_jailbroken=True) | Q(is_compromised=True)
            ).count(),
        },
        'activity': {
            'last_login': user.last_login.isoformat() if user.last_login else None,
            'days_since_login': (now - user.last_login).days if user.last_login else None,
            'account_age_days': (now - user.date_joined).days,
        }
    }


def get_user_security_status(user):
    """Determina lo stato di sicurezza di un utente"""
    compromised_devices = user.devices.filter(
        Q(is_rooted=True) | Q(is_jailbroken=True) | Q(is_compromised=True)
    ).count()
    
    if compromised_devices > 0:
        return 'high_risk'
    elif not user.is_active:
        return 'blocked'
    elif user.devices.filter(is_active=True).count() == 0:
        return 'no_devices'
    elif user.last_login and (timezone.now() - user.last_login).days > 30:
        return 'inactive'
    else:
        return 'secure'


def get_user_online_status(user):
    """Determina se l'utente è online"""
    if not user.last_login:
        return 'never'
    
    time_diff = timezone.now() - user.last_login
    
    if time_diff.total_seconds() < 300:  # 5 minuti
        return 'online'
    elif time_diff.total_seconds() < 3600:  # 1 ora
        return 'away'
    elif time_diff.days < 1:
        return 'recently_active'
    else:
        return 'offline'


def get_user_recent_activity(user):
    """Ottiene attività recente dell'utente"""
    recent_messages = Message.objects.filter(
        Q(sender__user=user) | Q(recipient__user=user),
        created_at__gte=timezone.now() - timedelta(hours=24)
    ).order_by('-created_at')[:10]
    
    activity = []
    for msg in recent_messages:
        activity.append({
            'type': 'message',
            'action': 'sent' if msg.sender.user == user else 'received',
            'target': msg.recipient.user.username if msg.sender.user == user else msg.sender.user.username,
            'message_type': msg.message_type,
            'timestamp': msg.created_at.isoformat(),
        })
    
    return activity


def get_client_ip(request):
    """Ottiene IP del client"""
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip


# API per ottenere opzioni filtri
@user_passes_test(is_superuser)
def get_filter_options(request):
    """API per ottenere opzioni per i filtri"""
    
    # Tipi dispositivo disponibili
    device_types = Device.objects.values_list('device_type', flat=True).distinct()
    
    # Gruppi disponibili (mock per ora)
    groups = [
        {'id': 1, 'name': 'Amministratori'},
        {'id': 2, 'name': 'Sviluppatori'},
        {'id': 3, 'name': 'Utenti Standard'},
    ]
    
    return JsonResponse({
        'device_types': list(device_types),
        'groups': groups,
        'status_options': [
            {'value': 'all', 'label': 'Tutti'},
            {'value': 'active', 'label': 'Attivi'},
            {'value': 'blocked', 'label': 'Bloccati'},
            {'value': 'online', 'label': 'Online'},
            {'value': 'staff', 'label': 'Staff'},
        ],
        'sort_options': [
            {'value': 'date_joined', 'label': 'Data registrazione'},
            {'value': 'last_login', 'label': 'Ultimo accesso'},
            {'value': 'username', 'label': 'Username'},
            {'value': 'email', 'label': 'Email'},
        ]
    })
