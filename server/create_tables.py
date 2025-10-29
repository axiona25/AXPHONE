#!/usr/bin/env python3
"""
Script per creare le tabelle del database per Secure VOX
"""

import sqlite3
import os
from pathlib import Path

def create_database():
    """Crea il database SQLite con le tabelle necessarie"""
    
    # Percorso del database
    db_path = Path(__file__).parent / "securevox.db"
    
    # Connessione al database
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    print("🗄️ Creazione database Secure VOX...")
    
    # Tabella utenti
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS auth_user (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            password VARCHAR(128) NOT NULL,
            last_login DATETIME,
            is_superuser BOOLEAN NOT NULL DEFAULT 0,
            username VARCHAR(150) NOT NULL UNIQUE,
            first_name VARCHAR(150) NOT NULL,
            last_name VARCHAR(150) NOT NULL,
            email VARCHAR(254) NOT NULL UNIQUE,
            is_staff BOOLEAN NOT NULL DEFAULT 0,
            is_active BOOLEAN NOT NULL DEFAULT 1,
            date_joined DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    print("✅ Tabella auth_user creata")
    
    # Tabella token di autenticazione
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS api_authtoken (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            encrypted_key TEXT NOT NULL UNIQUE,
            created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            expires_at DATETIME NOT NULL,
            is_active BOOLEAN NOT NULL DEFAULT 1,
            FOREIGN KEY (user_id) REFERENCES auth_user (id) ON DELETE CASCADE
        )
    ''')
    print("✅ Tabella api_authtoken creata")
    
    # Tabella profili utente estesi
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS user_profiles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL UNIQUE,
            bio TEXT,
            phone VARCHAR(20),
            location VARCHAR(100),
            date_of_birth DATE,
            avatar_url TEXT,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES auth_user (id) ON DELETE CASCADE
        )
    ''')
    print("✅ Tabella user_profiles creata")
    
    # Tabella per autenticazione social
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS social_accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            provider VARCHAR(50) NOT NULL,
            provider_id VARCHAR(255) NOT NULL,
            provider_email VARCHAR(254),
            provider_name VARCHAR(255),
            provider_avatar_url TEXT,
            access_token TEXT,
            refresh_token TEXT,
            token_expires_at DATETIME,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES auth_user (id) ON DELETE CASCADE,
            UNIQUE(provider, provider_id)
        )
    ''')
    print("✅ Tabella social_accounts creata")
    
    # Indici per performance
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_auth_user_email ON auth_user(email)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_auth_user_username ON auth_user(username)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_authtoken_user ON api_authtoken(user_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_authtoken_key ON api_authtoken(encrypted_key)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_authtoken_expires ON api_authtoken(expires_at)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_social_provider ON social_accounts(provider, provider_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_social_user ON social_accounts(user_id)')
    
    print("✅ Indici creati")
    
    # Commit e chiusura
    conn.commit()
    conn.close()
    
    print(f"🎉 Database creato con successo: {db_path}")
    return db_path


if __name__ == '__main__':
    create_database()
    print("\n🚀 Database pronto per l'uso!")
