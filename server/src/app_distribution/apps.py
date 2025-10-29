from django.apps import AppConfig


class AppDistributionConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'app_distribution'
    verbose_name = 'App Distribution'
    
    def ready(self):
        import app_distribution.signals
