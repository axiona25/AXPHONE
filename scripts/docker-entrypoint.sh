#!/bin/bash
# SecureVox API Server - Production Entrypoint Script

set -e

# Funzioni di utilità
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

log_warn() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARN: $1" >&2
}

# Attendi che il database sia pronto
wait_for_db() {
    log_info "Waiting for database connection..."
    
    max_tries=30
    count=0
    
    while [ $count -lt $max_tries ]; do
        if python manage.py check --database default > /dev/null 2>&1; then
            log_info "Database connection established"
            return 0
        fi
        
        count=$((count + 1))
        log_info "Database not ready, attempt $count/$max_tries..."
        sleep 2
    done
    
    log_error "Failed to connect to database after $max_tries attempts"
    exit 1
}

# Attendi Redis
wait_for_redis() {
    log_info "Waiting for Redis connection..."
    
    max_tries=30
    count=0
    
    while [ $count -lt $max_tries ]; do
        if python -c "
import redis
import os
try:
    r = redis.from_url(os.environ.get('REDIS_URL', 'redis://localhost:6379'))
    r.ping()
    print('Redis connected')
    exit(0)
except:
    exit(1)
" > /dev/null 2>&1; then
            log_info "Redis connection established"
            return 0
        fi
        
        count=$((count + 1))
        log_info "Redis not ready, attempt $count/$max_tries..."
        sleep 2
    done
    
    log_error "Failed to connect to Redis after $max_tries attempts"
    exit 1
}

# Esegui migrazioni database
run_migrations() {
    log_info "Running database migrations..."
    
    if python manage.py migrate --noinput; then
        log_info "Database migrations completed successfully"
    else
        log_error "Database migrations failed"
        exit 1
    fi
}

# Crea superuser se non esiste
create_superuser() {
    if [ -n "$DJANGO_SUPERUSER_EMAIL" ] && [ -n "$DJANGO_SUPERUSER_PASSWORD" ]; then
        log_info "Creating superuser if not exists..."
        
        python manage.py shell -c "
import os
from django.contrib.auth import get_user_model
User = get_user_model()
email = os.environ.get('DJANGO_SUPERUSER_EMAIL')
password = os.environ.get('DJANGO_SUPERUSER_PASSWORD')
if email and password and not User.objects.filter(email=email).exists():
    User.objects.create_superuser(
        email=email,
        password=password,
        username=email.split('@')[0]
    )
    print('Superuser created successfully')
else:
    print('Superuser already exists or credentials not provided')
"
    fi
}

# Validazione configurazione
validate_config() {
    log_info "Validating configuration..."
    
    # Controlla variabili obbligatorie
    required_vars=(
        "DJANGO_SECRET_KEY"
        "POSTGRES_HOST"
        "POSTGRES_DB"
        "POSTGRES_USER"
        "POSTGRES_PASSWORD"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    # Validazione Django
    if ! python manage.py check --deploy > /dev/null 2>&1; then
        log_warn "Django deployment checks failed (non-critical)"
    fi
    
    log_info "Configuration validation completed"
}

# Cleanup e ottimizzazioni
cleanup_and_optimize() {
    log_info "Running cleanup and optimization..."
    
    # Pulisci sessioni scadute
    python manage.py clearsessions > /dev/null 2>&1 || true
    
    # Ottimizza database (se necessario)
    if [ "$DJANGO_OPTIMIZE_DB" = "true" ]; then
        python manage.py migrate --run-syncdb > /dev/null 2>&1 || true
    fi
    
    log_info "Cleanup and optimization completed"
}

# Gestione segnali per graceful shutdown
graceful_shutdown() {
    log_info "Received shutdown signal, performing graceful shutdown..."
    
    # Termina processi worker se presenti
    if [ -f "/tmp/gunicorn.pid" ]; then
        kill -TERM $(cat /tmp/gunicorn.pid) 2>/dev/null || true
    fi
    
    log_info "Graceful shutdown completed"
    exit 0
}

# Registra gestori segnali
trap graceful_shutdown SIGTERM SIGINT

# Main execution
main() {
    log_info "Starting SecureVox API Server..."
    log_info "Environment: ${NODE_ENV:-development}"
    log_info "Debug mode: ${DEBUG:-1}"
    
    # Validazione iniziale
    validate_config
    
    # Attendi servizi esterni
    wait_for_db
    wait_for_redis
    
    # Setup database
    run_migrations
    create_superuser
    
    # Cleanup e ottimizzazioni
    cleanup_and_optimize
    
    # Determina comando di avvio in base agli argomenti
    if [ "$1" = "celery" ]; then
        if [ "$2" = "worker" ]; then
            log_info "Starting Celery worker..."
            exec celery -A src worker --loglevel=info --concurrency=4
        elif [ "$2" = "beat" ]; then
            log_info "Starting Celery beat scheduler..."
            exec celery -A src beat --loglevel=info
        else
            log_error "Unknown celery command: $2"
            exit 1
        fi
    elif [ "$1" = "migrate" ]; then
        log_info "Running migrations only..."
        run_migrations
        log_info "Migrations completed, exiting..."
        exit 0
    elif [ "$1" = "shell" ]; then
        log_info "Starting Django shell..."
        exec python manage.py shell
    elif [ "$1" = "test" ]; then
        log_info "Running tests..."
        exec python manage.py test
    else
        # Avvio server principale
        log_info "Starting Gunicorn server..."
        
        # Configurazione Gunicorn per produzione
        exec gunicorn \
            --bind 0.0.0.0:8000 \
            --workers ${GUNICORN_WORKERS:-4} \
            --worker-class gevent \
            --worker-connections ${GUNICORN_WORKER_CONNECTIONS:-1000} \
            --max-requests ${GUNICORN_MAX_REQUESTS:-1000} \
            --max-requests-jitter ${GUNICORN_MAX_REQUESTS_JITTER:-100} \
            --timeout ${GUNICORN_TIMEOUT:-120} \
            --keep-alive ${GUNICORN_KEEP_ALIVE:-5} \
            --preload \
            --pid /tmp/gunicorn.pid \
            --access-logfile - \
            --error-logfile - \
            --log-level info \
            src.wsgi:application
    fi
}

# Esegui main con tutti gli argomenti
main "$@"
