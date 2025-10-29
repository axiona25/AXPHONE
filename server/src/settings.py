import os
import logging
from pathlib import Path
from datetime import timedelta

BASE_DIR = Path(__file__).resolve().parent.parent

# Security - DISABLED FOR DEVELOPMENT
DEBUG = True  # Always True for development

# Simple secret key for development
SECRET_KEY = 'dev-secret-key-not-for-production-use-only'
ALLOWED_HOSTS = ['*']  # Allow all hosts for development

# Security Headers - ALL DISABLED FOR DEVELOPMENT
SECURE_BROWSER_XSS_FILTER = False
SECURE_CONTENT_TYPE_NOSNIFF = False
X_FRAME_OPTIONS = 'SAMEORIGIN'  # Less restrictive for development
SECURE_HSTS_SECONDS = 0
SECURE_HSTS_INCLUDE_SUBDOMAINS = False
SECURE_HSTS_PRELOAD = False

# CORS Configuration - SIMPLIFIED FOR DEVELOPMENT
CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True
CORS_ALLOW_HEADERS = ['*']  # Allow all headers
CORS_ALLOW_METHODS = ['*']  # Allow all methods
CORS_EXPOSE_HEADERS = ['*']  # Expose all headers

# Database
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "securevox.db",
    }
}

# Cache Configuration (using local memory for development)
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
        "LOCATION": "unique-snowflake",
    }
}

# Session Configuration
SESSION_ENGINE = "django.contrib.sessions.backends.cache"
SESSION_CACHE_ALIAS = "default"
SESSION_COOKIE_AGE = 3600  # 1 hour
SESSION_COOKIE_SECURE = not DEBUG

# Authentication Configuration
LOGIN_URL = '/admin/login/'
LOGIN_REDIRECT_URL = '/app-distribution/'
LOGOUT_REDIRECT_URL = '/app-distribution/'
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = 'Strict'

# Applications
INSTALLED_APPS = [
    "django.contrib.contenttypes",
    "django.contrib.auth",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "rest_framework.authtoken",
    "corsheaders",
    "channels",
    "api.apps.ApiConfig",
    "crypto",
    "notifications",
    "devices",
    "admin_panel",
    "app_distribution.apps.AppDistributionConfig",
]

# Middleware - SIMPLIFIED FOR DEVELOPMENT
MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    # "django.middleware.csrf.CsrfViewMiddleware",  # DISABLED FOR DEVELOPMENT
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    # Security middlewares disabled for development
]

# URLs
ROOT_URLCONF = "urls"
WSGI_APPLICATION = "wsgi.application"

# Templates
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

# Static Files
STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

# Media Files
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

# REST Framework
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.TokenAuthentication",  # Token DRF standard (1 token per utente, no scadenza)
        "rest_framework.authentication.SessionAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
    "DEFAULT_RENDERER_CLASSES": [
        "rest_framework.renderers.JSONRenderer",
    ],
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 20,
    # 🧪 THROTTLING COMPLETAMENTE DISABILITATO PER TESTING E2EE
    # "DEFAULT_THROTTLE_CLASSES": [
    #     "rest_framework.throttling.AnonRateThrottle",
    #     "rest_framework.throttling.UserRateThrottle",
    # ],
    # "DEFAULT_THROTTLE_RATES": {
    #     "anon": "100/hour",
    #     "user": "1000/hour",
    # }
}

# Logging Configuration
# Crea directory per i log se non esiste
import os
log_dir = BASE_DIR / "logs"
log_dir.mkdir(exist_ok=True)

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "verbose": {
            "format": "{levelname} {asctime} {module} {process:d} {thread:d} {message}",
            "style": "{",
        },
        "simple": {
            "format": "{levelname} {message}",
            "style": "{",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "verbose",
        },
        "file": {
            "class": "logging.FileHandler",
            "filename": str(log_dir / "django.log"),
            "formatter": "verbose",
        },
    },
    "root": {
        "handlers": ["console"],
        "level": "INFO",
    },
    "loggers": {
        "django": {
            "handlers": ["console"],
            "level": "INFO",
            "propagate": False,
        },
        "securevox": {
            "handlers": ["console", "file"],
            "level": "DEBUG" if DEBUG else "INFO",
            "propagate": False,
        },
    },
}

# Firebase Configuration - REMOVED (using internal notification system)

# TURN Server Configuration
TURN_SERVER = {
    "host": os.getenv("TURN_HOST", "turn"),
    "port": int(os.getenv("TURN_PORT", "3478")),
    "username": os.getenv("TURN_USERNAME", "securevox"),
    "password": os.getenv("TURN_PASSWORD", "changeme"),
    "realm": os.getenv("TURN_REALM", "securevox"),
}

# Janus SFU Configuration
JANUS_SFU = {
    "url": os.getenv("JANUS_URL", "http://sfu:8088"),
    "api_secret": os.getenv("JANUS_API_SECRET", "changeme"),
    "admin_secret": os.getenv("JANUS_ADMIN_SECRET", "changeme"),
}

# Crypto Configuration
CRYPTO_CONFIG = {
    "key_rotation_interval": timedelta(hours=24),
    "max_prekeys": 100,
    "prekey_batch_size": 20,
}

# Internationalization
LANGUAGE_CODE = "it-it"
TIME_ZONE = "Europe/Rome"
USE_I18N = True
USE_TZ = True

# Default primary key field type
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# Celery Configuration (using database for development)
CELERY_BROKER_URL = 'db+sqlite:///' + str(BASE_DIR / 'celery.db')
CELERY_RESULT_BACKEND = 'db+sqlite:///' + str(BASE_DIR / 'celery.db')
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_TIMEZONE = TIME_ZONE
CELERY_ENABLE_UTC = True
CELERY_TASK_ALWAYS_EAGER = DEBUG  # Esegui task sincronamente in debug
CELERY_TASK_EAGER_PROPAGATES = True

# Media files configuration
MEDIA_URL = '/api/media/download/'
MEDIA_ROOT = BASE_DIR / 'media'

# File upload settings
FILE_UPLOAD_MAX_MEMORY_SIZE = 50 * 1024 * 1024  # 50MB
DATA_UPLOAD_MAX_MEMORY_SIZE = 50 * 1024 * 1024  # 50MB
FILE_UPLOAD_PERMISSIONS = 0o644

# SECURITY FIX: Enhanced security settings for production
if not DEBUG:
    # Force HTTPS in production
    SECURE_SSL_REDIRECT = True
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    
    # Enhanced security headers
    SECURE_BROWSER_XSS_FILTER = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    X_FRAME_OPTIONS = 'DENY'
    SECURE_HSTS_SECONDS = 31536000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    
    # Validate ALLOWED_HOSTS in production
    if not ALLOWED_HOSTS or ALLOWED_HOSTS == ['*']:
        raise ValueError("ALLOWED_HOSTS must be properly configured in production")

# 🧪 THROTTLING DISABILITATO PER TESTING E2EE
# Enhanced rate limiting (relaxed for development)
# REST_FRAMEWORK['DEFAULT_THROTTLE_RATES'] = {
#     "anon": "1000/hour" if DEBUG else "50/hour",      # More permissive in development
#     "user": "5000/hour" if DEBUG else "500/hour",     # More permissive in development  
#     "login": "100/hour" if DEBUG else "10/hour",      # More permissive in development
# }

# Channels Configuration
ASGI_APPLICATION = 'src.asgi.application'

# Channel Layers Configuration
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {
            "hosts": [('127.0.0.1', 6379)],
        },
    },
}
