#!/usr/bin/env python
import os
import sys
import django

# Setup Django
sys.path.insert(0, '/Users/r.amoroso/Documents/Cursor/securevox/server/src')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'settings')
django.setup()

from django.contrib.auth.models import User
from admin_panel.models import UserProfile

print("=" * 80)
print("VERIFICA AVATAR UTENTI")
print("=" * 80)
print()

users = User.objects.all()
print(f"📊 Totale utenti: {users.count()}\n")

for user in users:
    print(f"👤 {user.username} (ID: {user.id})")
    print(f"   Email: {user.email}")
    print(f"   Nome: {user.first_name} {user.last_name}")
    
    try:
        profile = UserProfile.objects.get(user=user)
        if profile.avatar_url:
            print(f"   ✅ Avatar: {profile.avatar_url}")
        else:
            print(f"   ❌ Avatar: (vuoto)")
    except UserProfile.DoesNotExist:
        print(f"   ⚠️  Nessun profilo UserProfile")
    except Exception as e:
        print(f"   ❌ Errore: {e}")
    
    print()

print("=" * 80)

