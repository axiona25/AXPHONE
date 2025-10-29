# API di Autenticazione Social - Secure VOX

## Panoramica

Le API di autenticazione social permettono agli utenti di accedere a Secure VOX utilizzando i loro account Facebook, Google e Apple.

## Base URL

```
http://localhost:8002/api
```

## Endpoints

### 1. Stato del Servizio

**GET** `/auth/social/status`

Verifica lo stato del servizio di autenticazione social.

**Risposta:**
```json
{
  "success": true,
  "message": "Servizio di autenticazione social attivo",
  "supported_providers": ["facebook", "google", "apple"],
  "version": "1.0.0"
}
```

### 2. Provider Supportati

**GET** `/auth/social/providers`

Ottiene la lista dei provider di autenticazione supportati.

**Risposta:**
```json
{
  "success": true,
  "providers": [
    {
      "name": "facebook",
      "display_name": "Facebook",
      "icon": "facebook",
      "color": "#1877F2"
    },
    {
      "name": "google",
      "display_name": "Google",
      "icon": "google",
      "color": "#4285F4"
    },
    {
      "name": "apple",
      "display_name": "Apple",
      "icon": "apple",
      "color": "#000000"
    }
  ]
}
```

### 3. Login Facebook

**POST** `/auth/social/facebook`

Effettua il login utilizzando un token di accesso Facebook.

**Body:**
```json
{
  "access_token": "EAABwzLixnjYBAO..."
}
```

**Risposta di Successo:**
```json
{
  "success": true,
  "user": {
    "id": "123",
    "name": "Mario Rossi",
    "email": "mario.rossi@example.com",
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-01T00:00:00Z",
    "is_active": true
  },
  "token": "encrypted_auth_token_here",
  "message": "Login con Facebook effettuato con successo"
}
```

**Risposta di Errore:**
```json
{
  "success": false,
  "message": "Token Facebook non valido"
}
```

### 4. Login Google

**POST** `/auth/social/google`

Effettua il login utilizzando un token ID Google.

**Body:**
```json
{
  "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Risposta:** Stessa struttura del login Facebook.

### 5. Login Apple

**POST** `/auth/social/apple`

Effettua il login utilizzando un token di identità Apple.

**Body:**
```json
{
  "identity_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Risposta:** Stessa struttura del login Facebook.

### 6. Scollega Account Social

**POST** `/auth/social/unlink`

Scollega un account social dall'utente.

**Body:**
```json
{
  "user_id": "123",
  "provider": "facebook"
}
```

**Risposta:**
```json
{
  "success": true,
  "message": "Account facebook scollegato con successo"
}
```

## Database

### Tabelle Utilizzate

1. **auth_user** - Utenti del sistema
2. **api_authtoken** - Token di autenticazione cifrati
3. **user_profiles** - Profili utente estesi
4. **social_accounts** - Account social collegati

### Struttura social_accounts

```sql
CREATE TABLE social_accounts (
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
);
```

## Sicurezza

- I token di autenticazione sono cifrati usando Fernet (AES 128)
- I token hanno una scadenza di 24 ore
- I token vengono invalidati al logout
- I dati sensibili non vengono memorizzati in chiaro

## Integrazione Flutter

Il client Flutter utilizza il servizio `SocialAuthService` per comunicare con le API:

```dart
// Login con Facebook
final result = await SocialAuthService.loginWithFacebook(accessToken);

// Login con Google
final result = await SocialAuthService.loginWithGoogle(idToken);

// Login con Apple
final result = await SocialAuthService.loginWithApple(identityToken);
```

## Test

Per testare le API, esegui:

```bash
python test_social_api.py
```

## Avvio del Server

```bash
python social_auth_api.py
```

Il server sarà disponibile su `http://localhost:8002`
