from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from app_distribution.models import AppBuild
import os


class Command(BaseCommand):
    help = 'Setup iniziale per il sistema di distribuzione app'

    def add_arguments(self, parser):
        parser.add_argument(
            '--create-demo-data',
            action='store_true',
            help='Crea dati di demo per testare il sistema',
        )

    def handle(self, *args, **options):
        self.stdout.write(
            self.style.SUCCESS('🚀 Configurazione App Distribution...')
        )

        # Crea directory per i media se non esistono
        media_dirs = [
            'media/app_builds',
            'media/app_icons',
        ]
        
        for media_dir in media_dirs:
            os.makedirs(media_dir, exist_ok=True)
            self.stdout.write(f'✅ Directory creata: {media_dir}')

        # Crea dati di demo se richiesto
        if options['create_demo_data']:
            self.create_demo_data()

        self.stdout.write(
            self.style.SUCCESS(
                '\n🎉 Setup completato!\n\n'
                'Prossimi passi:\n'
                '1. Accedi all\'admin: http://localhost:8001/admin/\n'
                '2. Carica le tue app builds\n'
                '3. Visita: http://localhost:8001/app-distribution/\n'
            )
        )

    def create_demo_data(self):
        """Crea dati di demo per testare il sistema"""
        self.stdout.write('📦 Creazione dati di demo...')
        
        # Verifica che esista almeno un utente admin
        admin_user = User.objects.filter(is_superuser=True).first()
        if not admin_user:
            admin_user = User.objects.create_superuser(
                username='admin',
                email='admin@securevox.com',
                password='admin123'
            )
            self.stdout.write('👤 Utente admin creato (admin/admin123)')

        # Crea build di esempio (senza file reali per ora)
        demo_builds = [
            {
                'name': 'SecureVOX iOS',
                'platform': 'ios',
                'version': '1.0.0',
                'build_number': '1',
                'bundle_id': 'com.securevox.app',
                'description': 'App di comunicazione sicura per iOS',
                'release_notes': 'Prima versione beta con chat e chiamate sicure',
                'is_beta': True,
                'min_os_version': '14.0'
            },
            {
                'name': 'SecureVOX Android',
                'platform': 'android',
                'version': '1.0.0',
                'build_number': '1',
                'bundle_id': 'com.securevox.app',
                'description': 'App di comunicazione sicura per Android',
                'release_notes': 'Prima versione beta con chat e chiamate sicure',
                'is_beta': True,
                'min_os_version': '8.0'
            }
        ]

        for build_data in demo_builds:
            build, created = AppBuild.objects.get_or_create(
                platform=build_data['platform'],
                bundle_id=build_data['bundle_id'],
                version=build_data['version'],
                build_number=build_data['build_number'],
                defaults={
                    **build_data,
                    'uploaded_by': admin_user,
                    'status': 'ready',
                    'is_active': False  # Disattivata finché non si carica un file reale
                }
            )
            
            if created:
                self.stdout.write(f'📱 Build demo creata: {build.name} v{build.version}')
            else:
                self.stdout.write(f'📱 Build demo già esistente: {build.name} v{build.version}')

        self.stdout.write(
            self.style.WARNING(
                '\n⚠️  Le build demo sono disattivate perché non hanno file reali.\n'
                '   Carica i file .ipa/.apk tramite l\'admin per attivarle.\n'
            )
        )
