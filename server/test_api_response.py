#!/usr/bin/env python
import os
import sys
import django
import json

# Setup Django
sys.path.insert(0, '/Users/r.amoroso/Documents/Cursor/securevox/server/src')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'settings')
django.setup()

from django.contrib.auth.models import User
from admin_panel.models import UserProfile
from api.models import UserStatus

print("=" * 80)
print("TEST API RESPONSE - users_list()")
print("=" * 80)
print()

# Simula la vista users_list
users = User.objects.all()
users_data = []

for user in users:
    # Recupera lo status se esiste
    try:
        user_status = UserStatus.objects.get(user=user)
        is_online = user_status.status == 'online' and user_status.is_logged_in
        last_seen = user_status.last_seen
        e2e_enabled = bool(user_status.e2e_public_key)
    except UserStatus.DoesNotExist:
        is_online = False
        last_seen = None
        e2e_enabled = False
    
    # Costruisce full_name da first_name e last_name
    full_name = f"{user.first_name} {user.last_name}".strip()
    if not full_name:
        full_name = user.username
    
    # Ottieni l'avatar_url dal profilo se esiste
    avatar_url = ''
    try:
        if hasattr(user, 'profile') and user.profile.avatar_url:
            avatar_url = user.profile.avatar_url
    except Exception as e:
        print(f"⚠️  Errore recupero avatar per {user.username}: {e}")
    
    users_data.append({
        'id': user.id,
        'username': user.username,
        'full_name': full_name,
        'avatar_url': avatar_url,
    })

print(json.dumps(users_data, indent=2))
print()
print("=" * 80)

