from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from django.contrib.auth.models import AnonymousUser
from .models import AuthToken
from django.utils import timezone
from django.core.cache import cache
import logging
import hashlib

logger = logging.getLogger('securevox')


class CustomTokenAuthentication(BaseAuthentication):
    """Autenticazione personalizzata con token con durata 24 ore"""
    
    def authenticate(self, request):
        """Autentica l'utente usando il token personalizzato con caching"""
        auth_header = request.META.get('HTTP_AUTHORIZATION', '')
        
        if not auth_header.startswith('Token '):
            return None
        
        token_key = auth_header.split(' ')[1]
        
        # Crea una chiave di cache basata sull'hash del token per sicurezza
        token_hash = hashlib.sha256(token_key.encode()).hexdigest()[:16]
        cache_key = f"auth_token_{token_hash}"
        
        # Prova a ottenere il token dalla cache
        cached_result = cache.get(cache_key)
        if cached_result:
            user_id, token_id = cached_result
            try:
                token = AuthToken.objects.get(id=token_id, is_active=True)
                if token.is_valid():
                    logger.debug(f"CustomTokenAuth - Token cache hit per utente: {token.user.username}")
                    return (token.user, token)
                else:
                    # Token scaduto, rimuovi dalla cache
                    cache.delete(cache_key)
            except AuthToken.DoesNotExist:
                # Token non esiste più, rimuovi dalla cache
                cache.delete(cache_key)
        
        logger.info(f"CustomTokenAuth - Token ricevuto: {token_key[:20]}...")
        
        try:
            # Cerca il token nel database confrontando con il token decrittato
            tokens = AuthToken.objects.filter(is_active=True)
            token = None
            for t in tokens:
                if t.get_token() == token_key:
                    token = t
                    break
            
            if not token:
                logger.warning(f"CustomTokenAuth - Token non trovato: {token_key[:20]}...")
                raise AuthenticationFailed('Token non valido')
            
            logger.info(f"CustomTokenAuth - Token trovato per utente: {token.user.username}")
            
            # Verifica se il token è valido (non scaduto e integro)
            if not token.is_valid():
                # Disattiva il token non valido
                token.is_active = False
                token.save()
                logger.info(f"CustomTokenAuth - Token non valido per utente {token.user.username}")
                raise AuthenticationFailed('Token scaduto o non valido')
            
            # Salva in cache per 5 minuti
            cache.set(cache_key, (token.user.id, token.id), 300)
            
            logger.info(f"CustomTokenAuth - Autenticazione riuscita per: {token.user.username}")
            return (token.user, token)
            
        except AuthToken.DoesNotExist:
            logger.warning(f"CustomTokenAuth - Token non trovato nel database")
            raise AuthenticationFailed('Token non valido')
        except Exception as e:
            logger.error(f"CustomTokenAuth - Errore durante l'autenticazione: {e}")
            raise AuthenticationFailed('Errore di autenticazione')
    
    def authenticate_header(self, request):
        """Restituisce l'header di autenticazione richiesto"""
        return 'Token'
