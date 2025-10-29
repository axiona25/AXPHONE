"""
Sistema di protezione password per SecureVox
Impedisce la modifica delle password degli utenti esistenti
"""
from django.contrib.auth.models import User
from django.core.exceptions import PermissionDenied
from django.db import transaction
import logging

logger = logging.getLogger('securevox')

class PasswordProtection:
    """Classe per proteggere le password degli utenti esistenti"""
    
    # Lista degli utenti protetti (quelli creati dagli utenti reali)
    PROTECTED_USERS = [
        'r.amoroso80@gmail.com',
        'r.dicamillo69@gmail.com',
    ]
    
    @classmethod
    def is_protected_user(cls, user):
        """Verifica se un utente è protetto"""
        if isinstance(user, str):
            # Se è un'email
            return user.lower() in [email.lower() for email in cls.PROTECTED_USERS]
        elif isinstance(user, User):
            # Se è un oggetto User
            return user.email.lower() in [email.lower() for email in cls.PROTECTED_USERS]
        return False
    
    @classmethod
    def can_modify_password(cls, user, action="modify"):
        """Verifica se è possibile modificare la password di un utente"""
        if cls.is_protected_user(user):
            logger.warning(f"Tentativo di {action} password per utente protetto: {user.email if hasattr(user, 'email') else user}")
            raise PermissionDenied(
                f"Non è possibile modificare la password di questo utente. "
                f"Usa il sistema di recupero password integrato."
            )
        return True
    
    
    @classmethod
    def get_protected_users_info(cls):
        """Restituisce informazioni sugli utenti protetti"""
        protected_info = []
        for email in cls.PROTECTED_USERS:
            try:
                user = User.objects.get(email=email)
                protected_info.append({
                    'email': user.email,
                    'username': user.username,
                    'name': f"{user.first_name} {user.last_name}".strip(),
                    'is_active': user.is_active,
                    'date_joined': user.date_joined,
                })
            except User.DoesNotExist:
                protected_info.append({
                    'email': email,
                    'username': 'N/A',
                    'name': 'N/A',
                    'is_active': False,
                    'date_joined': None,
                })
        return protected_info


def protect_password_modification(func):
    """Decorator per proteggere le funzioni di modifica password"""
    def wrapper(*args, **kwargs):
        # Estrai l'utente dai parametri
        user = None
        if 'user' in kwargs:
            user = kwargs['user']
        elif len(args) > 0:
            user = args[0]
        
        if user:
            PasswordProtection.can_modify_password(user, "modify")
        
        return func(*args, **kwargs)
    return wrapper


# Middleware per proteggere le password
class PasswordProtectionMiddleware:
    """Middleware per proteggere le password degli utenti"""
    
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        response = self.get_response(request)
        return response
    
    def process_view(self, request, view_func, view_args, view_kwargs):
        """Intercetta le richieste di modifica password"""
        if request.method == 'POST':
            # Controlla se è una richiesta di modifica password
            if 'password' in request.POST or 'new_password' in request.POST:
                # Estrai l'email dall'utente corrente o dalla richiesta
                user_email = None
                if hasattr(request, 'user') and request.user.is_authenticated:
                    user_email = request.user.email
                elif 'email' in request.POST:
                    user_email = request.POST['email']
                
                if user_email and PasswordProtection.is_protected_user(user_email):
                    logger.warning(f"Tentativo di modifica password protetta per: {user_email}")
                    return JsonResponse({
                        'message': 'Non è possibile modificare la password di questo utente. Usa il sistema di recupero password.',
                        'error': 'PASSWORD_PROTECTED'
                    }, status=403)
        
        return None
