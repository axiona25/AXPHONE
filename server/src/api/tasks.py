"""
Task Celery per la gestione automatica delle chat
"""

from celery import shared_task
from django.utils import timezone
from .models import Chat
import logging

logger = logging.getLogger('securevox')


@shared_task
def cleanup_expired_gestation_chats():
    """
    Pulisce automaticamente le chat il cui periodo di gestazione è scaduto
    Deve essere eseguito periodicamente (es. ogni ora)
    """
    try:
        # Trova chat in gestazione scadute
        expired_chats = Chat.objects.filter(
            is_in_gestation=True,
            gestation_expires_at__lt=timezone.now()
        )
        
        deleted_count = 0
        for chat in expired_chats:
            logger.info(f"🗑️ Pulizia automatica chat scaduta: {chat.id} ({chat.name})")
            
            # Eliminazione definitiva
            chat.complete_deletion()
            deleted_count += 1
        
        logger.info(f"✅ Cleanup completato: {deleted_count} chat eliminate automaticamente")
        return f"Eliminated {deleted_count} expired chats"
        
    except Exception as e:
        logger.error(f"❌ Errore cleanup chat gestazione: {e}")
        return f"Error: {e}"


@shared_task
def check_pending_deletion_notifications():
    """
    Controlla e invia notifiche per chat in attesa di eliminazione
    """
    try:
        # Trova chat con notifiche pendenti
        pending_chats = Chat.objects.filter(
            is_in_gestation=True,
            pending_deletion_notification_sent=False
        )
        
        sent_count = 0
        for chat in pending_chats:
            try:
                other_participant = None
                if not chat.is_group and chat.deletion_requested_by:
                    other_participant = chat.get_other_participant(chat.deletion_requested_by)
                
                if other_participant:
                    # Invia notifica
                    notification_payload = {
                        'recipient_id': str(other_participant.id),
                        'title': f'{chat.deletion_requested_by.first_name or chat.deletion_requested_by.username} ha eliminato la chat',
                        'body': f'Vuoi eliminare definitivamente la chat "{chat.name}" o mantenerla per 7 giorni?',
                        'data': {
                            'notification_type': 'chat_deletion_request',
                            'chat_id': str(chat.id),
                            'requesting_user_id': str(chat.deletion_requested_by.id),
                            'requesting_user_name': chat.deletion_requested_by.first_name or chat.deletion_requested_by.username,
                            'expires_at': chat.gestation_expires_at.isoformat(),
                        },
                        'notification_type': 'chat_deletion_request'
                    }
                    
                    # Invia al server notify
                    import requests
                    response = requests.post(
                        'http://localhost:8002/send',
                        json=notification_payload,
                        timeout=5
                    )
                    
                    if response.status_code == 200:
                        chat.pending_deletion_notification_sent = True
                        chat.save()
                        sent_count += 1
                        logger.info(f"📱 Notifica eliminazione chat inviata a {other_participant.username}")
                    else:
                        logger.warning(f"❌ Errore invio notifica eliminazione: {response.status_code}")
                        
            except Exception as notify_error:
                logger.warning(f"❌ Errore notifica per chat {chat.id}: {notify_error}")
        
        logger.info(f"✅ Notifiche inviate: {sent_count}")
        return f"Sent {sent_count} notifications"
        
    except Exception as e:
        logger.error(f"❌ Errore check notifiche: {e}")
        return f"Error: {e}"
