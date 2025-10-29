from celery import shared_task
from django.utils import timezone
from .models import NotificationQueue, NotificationLog
import logging
import requests
import json

logger = logging.getLogger('securevox')

# URL del servizio di notifiche interno
NOTIFICATION_SERVICE_URL = "http://localhost:8002"

def send_internal_notification(device, notification_type, encrypted_payload, priority='normal'):
    """
    Invia notifica tramite il nostro servizio interno con supporto per suoni e badge
    """
    try:
        # Prepara il payload per il servizio di notifiche
        notification_data = {
            "recipient_id": device.user_id,
            "title": get_notification_title(notification_type),
            "body": get_notification_body(notification_type, encrypted_payload),
            "data": {
                "type": notification_type,
                "priority": priority,
                "sound": True,  # Abilita suono
                "badge": True,  # Abilita badge contatore
                "encrypted_payload": encrypted_payload.hex() if encrypted_payload else None
            },
            "sender_id": "system",
            "timestamp": timezone.now().isoformat(),
            "notification_type": notification_type
        }
        
        # Invia al servizio di notifiche
        response = requests.post(
            f"{NOTIFICATION_SERVICE_URL}/send",
            json=notification_data,
            timeout=10
        )
        
        if response.status_code == 200:
            logger.info(f"Notification sent successfully to {device.user_id}")
            return True
        else:
            logger.error(f"Notification service error: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        logger.error(f"Error sending internal notification: {e}")
        return False

def get_notification_title(notification_type):
    """Genera titolo appropriato per tipo di notifica"""
    titles = {
        'message': 'Nuovo messaggio',
        'call': 'Chiamata in arrivo',
        'remote_wipe': 'Richiesta di cancellazione remota',
        'key_rotation': 'Rotazione chiavi di sicurezza'
    }
    return titles.get(notification_type, 'Notifica SecureVOX')

def get_notification_body(notification_type, encrypted_payload):
    """Genera corpo appropriato per tipo di notifica"""
    bodies = {
        'message': 'Hai ricevuto un nuovo messaggio cifrato',
        'call': 'Chiamata vocale in arrivo',
        'remote_wipe': 'Richiesta di cancellazione dati remota',
        'key_rotation': 'Le chiavi di sicurezza sono state aggiornate'
    }
    return bodies.get(notification_type, 'Nuova notifica da SecureVOX')

def send_batch_internal_notifications(batch_data):
    """
    Invia notifiche in batch tramite il servizio interno
    """
    results = []
    
    for device, notification_type, encrypted_payload, priority in batch_data:
        try:
            success = send_internal_notification(device, notification_type, encrypted_payload, priority)
            results.append(type('Result', (), {'success': success})())
        except Exception as e:
            logger.error(f"Error in batch notification: {e}")
            results.append(type('Result', (), {'success': False})())
    
    return results

@shared_task
def send_notification(notification_id):
    """
    Task per inviare una singola notifica tramite il nostro servizio interno
    """
    try:
        notification = NotificationQueue.objects.get(id=notification_id)
        
        # Invia la notifica tramite il nostro servizio interno
        success = send_internal_notification(
            device=notification.device,
            notification_type=notification.notification_type,
            encrypted_payload=notification.encrypted_payload,
            priority=notification.priority
        )
        
        if success:
            notification.sent_at = timezone.now()
            notification.save()
            
            # Crea log
            NotificationLog.objects.create(
                notification=notification,
                response_status='success',
                response_data={'sent_at': notification.sent_at.isoformat()}
            )
            
            logger.info(f"Notification {notification_id} sent successfully")
        else:
            notification.failed_at = timezone.now()
            notification.retry_count += 1
            notification.save()
            
            # Crea log
            NotificationLog.objects.create(
                notification=notification,
                response_status='failed',
                response_data={'error': 'Internal notification service failed'}
            )
            
            logger.warning(f"Notification {notification_id} failed to send")
        
        return success
        
    except NotificationQueue.DoesNotExist:
        logger.error(f"Notification {notification_id} not found")
        return False
    except Exception as e:
        logger.error(f"Error sending notification {notification_id}: {e}")
        return False


@shared_task
def process_notification_queue():
    """
    Task per processare la coda delle notifiche
    """
    try:
        # Ottieni notifiche da inviare
        notifications = NotificationQueue.objects.filter(
            sent_at__isnull=True,
            failed_at__isnull=True,
            retry_count__lt=3,
            scheduled_at__lte=timezone.now()
        ).select_related('device')[:100]  # Processa max 100 alla volta
        
        if not notifications:
            logger.debug("No notifications to process")
            return 0
        
        # Prepara batch per il servizio interno
        batch_data = []
        for notification in notifications:
            batch_data.append((
                notification.device,
                notification.notification_type,
                notification.encrypted_payload,
                notification.priority
            ))
        
        # Invia in batch tramite servizio interno
        results = send_batch_internal_notifications(batch_data)
        
        # Aggiorna stato notifiche
        success_count = 0
        for i, notification in enumerate(notifications):
            if i < len(results) and results[i].success:
                notification.sent_at = timezone.now()
                notification.save()
                
                NotificationLog.objects.create(
                    notification=notification,
                    response_status='success',
                    response_data={'sent_at': notification.sent_at.isoformat()}
                )
                success_count += 1
            else:
                notification.retry_count += 1
                if notification.retry_count >= notification.max_retries:
                    notification.failed_at = timezone.now()
                
                notification.save()
                
                NotificationLog.objects.create(
                    notification=notification,
                    response_status='failed',
                    response_data={'error': 'Batch send failed'}
                )
        
        logger.info(f"Processed {len(notifications)} notifications, {success_count} successful")
        return success_count
        
    except Exception as e:
        logger.error(f"Error processing notification queue: {e}")
        return 0


@shared_task
def cleanup_old_notifications():
    """
    Task per pulire notifiche vecchie
    """
    try:
        from datetime import timedelta
        
        # Rimuovi notifiche inviate più di 7 giorni fa
        cutoff_date = timezone.now() - timedelta(days=7)
        
        deleted_count = NotificationQueue.objects.filter(
            sent_at__isnull=False,
            sent_at__lt=cutoff_date
        ).delete()[0]
        
        logger.info(f"Cleaned up {deleted_count} old notifications")
        return deleted_count
        
    except Exception as e:
        logger.error(f"Error cleaning up notifications: {e}")
        return 0


@shared_task
def retry_failed_notifications():
    """
    Task per riprovare notifiche fallite
    """
    try:
        # Trova notifiche fallite che possono essere riprovate
        failed_notifications = NotificationQueue.objects.filter(
            failed_at__isnull=False,
            retry_count__lt=3,
            scheduled_at__gte=timezone.now() - timezone.timedelta(hours=24)  # Solo ultime 24h
        )
        
        retry_count = 0
        for notification in failed_notifications:
            # Reset stato per riprova
            notification.failed_at = None
            notification.retry_count += 1
            notification.scheduled_at = timezone.now()
            notification.save()
            
            # Invia di nuovo
            send_notification.delay(str(notification.id))
            retry_count += 1
        
        logger.info(f"Retrying {retry_count} failed notifications")
        return retry_count
        
    except Exception as e:
        logger.error(f"Error retrying notifications: {e}")
        return 0
