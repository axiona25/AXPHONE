from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from django.contrib.auth.models import User
from django.core.mail import send_mail
from django.conf import settings
from .models import AppBuild, AppDownload
import logging

logger = logging.getLogger(__name__)


@receiver(post_save, sender=AppBuild)
def notify_new_build(sender, instance, created, **kwargs):
    """Notifica agli utenti quando viene creata una nuova build"""
    if created and instance.is_active:
        try:
            # Invia notifica a tutti gli utenti autorizzati
            users_to_notify = []
            
            if instance.allowed_users.exists():
                # Se ci sono utenti specifici autorizzati
                users_to_notify = instance.allowed_users.all()
            else:
                # Altrimenti notifica tutti gli utenti attivi
                users_to_notify = User.objects.filter(is_active=True)
            
            # Prepara il messaggio
            subject = f"Nuova build disponibile: {instance.name} v{instance.version}"
            
            platform_icon = "📱" if instance.platform == "ios" else "🤖"
            beta_text = " (BETA)" if instance.is_beta else ""
            
            message = f"""
Ciao!

È disponibile una nuova build di {instance.name}:

{platform_icon} Piattaforma: {instance.get_platform_display()}
📦 Versione: {instance.version} (Build {instance.build_number}){beta_text}
📅 Data: {instance.created_at.strftime('%d/%m/%Y %H:%M')}
👤 Caricata da: {instance.uploaded_by.username}

{instance.description if instance.description else ''}

Scarica ora: {settings.ALLOWED_HOSTS[0] if settings.ALLOWED_HOSTS and settings.ALLOWED_HOSTS[0] != '*' else 'localhost:8001'}/app-distribution/build/{instance.id}/

---
SecureVOX App Distribution
            """.strip()
            
            # Invia email agli utenti (se configurato)
            if hasattr(settings, 'EMAIL_HOST') and settings.EMAIL_HOST:
                recipient_emails = [user.email for user in users_to_notify if user.email]
                if recipient_emails:
                    send_mail(
                        subject,
                        message,
                        settings.DEFAULT_FROM_EMAIL,
                        recipient_emails,
                        fail_silently=True
                    )
                    logger.info(f"Email notification sent for build {instance.id} to {len(recipient_emails)} users")
            
            # Qui potresti aggiungere notifiche push se necessario
            # send_push_notification(users_to_notify, subject, instance.description)
            
        except Exception as e:
            logger.error(f"Error sending notification for build {instance.id}: {e}")


@receiver(post_save, sender=AppBuild)
def update_build_status(sender, instance, **kwargs):
    """Aggiorna lo stato della build in base al file"""
    if instance.app_file and instance.status == 'uploading':
        try:
            # Verifica che il file esista
            if instance.app_file.size > 0:
                instance.status = 'ready'
                instance.save(update_fields=['status'])
                logger.info(f"Build {instance.id} status updated to ready")
        except Exception as e:
            instance.status = 'failed'
            instance.save(update_fields=['status'])
            logger.error(f"Build {instance.id} failed: {e}")


@receiver(post_save, sender=AppDownload)
def track_download_analytics(sender, instance, created, **kwargs):
    """Traccia analytics per i download"""
    if created:
        try:
            # Log del download per analytics
            logger.info(
                f"Download: {instance.app_build.name} v{instance.app_build.version} "
                f"by {instance.user.username if instance.user else 'anonymous'} "
                f"from {instance.ip_address}"
            )
            
            # Qui potresti inviare dati a servizi di analytics esterni
            # send_to_analytics({
            #     'event': 'app_download',
            #     'app_name': instance.app_build.name,
            #     'version': instance.app_build.version,
            #     'platform': instance.app_build.platform,
            #     'user_id': instance.user.id if instance.user else None,
            #     'timestamp': instance.downloaded_at
            # })
            
        except Exception as e:
            logger.error(f"Error tracking download analytics: {e}")


def send_push_notification(users, title, body):
    """
    Invia notifiche push agli utenti (da implementare con Firebase/APNs)
    """
    # Implementazione placeholder per notifiche push
    # Qui integreresti Firebase Cloud Messaging o Apple Push Notification Service
    
    for user in users:
        try:
            # Esempio di come potresti strutturare una notifica push
            notification_data = {
                'title': title,
                'body': body,
                'click_action': '/app-distribution/',
                'user_id': user.id
            }
            
            # send_fcm_notification(notification_data)
            logger.info(f"Push notification would be sent to user {user.username}")
            
        except Exception as e:
            logger.error(f"Error sending push notification to user {user.id}: {e}")


# Funzioni di utilità per le notifiche
def notify_build_ready(build_id):
    """Notifica che una build è pronta (da usare in task asincroni)"""
    try:
        build = AppBuild.objects.get(id=build_id)
        if build.status == 'ready' and build.is_active:
            notify_new_build(AppBuild, build, created=False)
    except AppBuild.DoesNotExist:
        logger.error(f"Build {build_id} not found for notification")


def get_notification_preferences(user):
    """Ottiene le preferenze di notifica dell'utente"""
    # Placeholder per future preferenze utente
    return {
        'email_notifications': True,
        'push_notifications': True,
        'platforms': ['ios', 'android']  # Piattaforme di interesse
    }
