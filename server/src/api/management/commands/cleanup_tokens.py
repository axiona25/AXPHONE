from django.core.management.base import BaseCommand
from django.utils import timezone
from src.api.models import AuthToken
import logging

logger = logging.getLogger('securevox')


class Command(BaseCommand):
    help = 'Pulisce i token di autenticazione scaduti e non validi'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Mostra solo i token che verrebbero eliminati senza eliminarli',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        
        # Trova tutti i token scaduti o non validi
        expired_tokens = AuthToken.objects.filter(
            expires_at__lt=timezone.now()
        )
        
        invalid_tokens = []
        for token in AuthToken.objects.filter(is_active=True):
            if not token.is_valid():
                invalid_tokens.append(token)
        
        total_tokens = expired_tokens.count() + len(invalid_tokens)
        
        if dry_run:
            self.stdout.write(
                self.style.WARNING(
                    f'DRY RUN: Trovati {total_tokens} token da eliminare'
                )
            )
            
            for token in expired_tokens:
                self.stdout.write(f'  - Token scaduto per {token.user.username} (expires: {token.expires_at})')
            
            for token in invalid_tokens:
                self.stdout.write(f'  - Token non valido per {token.user.username} (created: {token.created})')
        else:
            # Elimina i token scaduti
            expired_count = expired_tokens.count()
            expired_tokens.delete()
            
            # Disattiva i token non validi
            invalid_count = len(invalid_tokens)
            for token in invalid_tokens:
                token.is_active = False
                token.save()
            
            self.stdout.write(
                self.style.SUCCESS(
                    f'Eliminati {expired_count} token scaduti e disattivati {invalid_count} token non validi'
                )
            )
            
            logger.info(f'Token cleanup completed: {expired_count} expired, {invalid_count} invalid')
