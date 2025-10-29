from django.contrib.auth.models import AnonymousUser
from django.utils.deprecation import MiddlewareMixin
from .models import AuthToken
from django.utils import timezone
import logging

logger = logging.getLogger('securevox')


class AuthTokenMiddleware(MiddlewareMixin):
    """Middleware per l'autenticazione con token personalizzati"""
    
    def process_request(self, request):
        """Processa la richiesta per verificare il token di autenticazione"""
        print("MIDDLEWARE EXECUTED")
        # Ottieni il token dall'header Authorization
        auth_header = request.META.get('HTTP_AUTHORIZATION', '')
        print(f"Auth header: {auth_header}")
        logger.info(f"Auth header: {auth_header}")
        
        if auth_header.startswith('Token '):
            token_key = auth_header.split(' ')[1]
            logger.info(f"Token key: {token_key[:20]}...")
            
            try:
                # Cerca il token nel database confrontando con il token decrittato
                tokens = AuthToken.objects.filter(is_active=True)
                token = None
                for t in tokens:
                    if t.get_token() == token_key:
                        token = t
                        break
                
                if not token:
                    logger.warning(f"Token not found: {token_key[:20]}...")
                    return
                
                logger.info(f"Token found for user: {token.user.username}")
                
                # Verifica se il token è valido (non scaduto e integro)
                if not token.is_valid():
                    # Disattiva il token non valido
                    token.is_active = False
                    token.save()
                    logger.info(f"Invalid token for user {token.user.username}")
                    return
                
                # Imposta l'utente nella richiesta
                request.user = token.user
                request.auth_token = token
                logger.info(f"User set: {request.user.username}")
                
            except Exception as e:
                # Errore durante la verifica del token
                logger.warning(f"Token verification error: {e}")
                return
        
        # Se non c'è token o è invalido, l'utente rimane AnonymousUser
        if not hasattr(request, 'user'):
            request.user = AnonymousUser()
            logger.info("No user set, using AnonymousUser")
