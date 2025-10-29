import os
from celery import Celery
from django.conf import settings

# Imposta la variabile d'ambiente per Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'src.settings')

# Crea l'istanza Celery
app = Celery('securevox')

# Configura Celery usando le impostazioni Django
app.config_from_object('django.conf:settings', namespace='CELERY')

# Auto-scopre i task nelle app Django
app.autodiscover_tasks()

# Configurazione specifica per SecureVOX
app.conf.update(
    # Broker (usa le impostazioni già definite in settings.py)
    broker_url=settings.CELERY_BROKER_URL,
    result_backend=settings.CELERY_RESULT_BACKEND,
    
    # Serializzazione
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    
    # Timezone
    timezone=settings.TIME_ZONE,
    enable_utc=True,
    
    # Task routing
    task_routes={
        'notifications.tasks.send_notification': {'queue': 'notifications'},
        'notifications.tasks.process_notification_queue': {'queue': 'notifications'},
        'notifications.tasks.cleanup_old_notifications': {'queue': 'maintenance'},
        'notifications.tasks.retry_failed_notifications': {'queue': 'notifications'},
    },
    
    # Task execution
    task_acks_late=True,
    worker_prefetch_multiplier=1,
    task_reject_on_worker_lost=True,
    
    # Monitoring
    worker_send_task_events=True,
    task_send_sent_event=True,
    
    # Beat schedule (per task periodici)
    beat_schedule={
        'process-notification-queue': {
            'task': 'notifications.tasks.process_notification_queue',
            'schedule': 30.0,  # Ogni 30 secondi
        },
        'cleanup-old-notifications': {
            'task': 'notifications.tasks.cleanup_old_notifications',
            'schedule': 3600.0,  # Ogni ora
        },
        'retry-failed-notifications': {
            'task': 'notifications.tasks.retry_failed_notifications',
            'schedule': 300.0,  # Ogni 5 minuti
        },
    },
)


@app.task(bind=True)
def debug_task(self):
    """Task di debug per testare Celery"""
    print(f'Request: {self.request!r}')
    return 'Celery is working!'
