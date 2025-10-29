# Importa Celery per auto-discovery (solo se disponibile)
try:
    from .celery import app as celery_app
    __all__ = ('celery_app',)
except ImportError:
    __all__ = ()