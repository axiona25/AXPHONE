#!/bin/bash

# Script per avviare il server Django con WebSocket su porta 8001
echo "🛡️ Avvio SecureVOX Server con WebSocket Real-time..."

# Vai nella directory server
cd server

# Attiva l'ambiente virtuale
if [ -f "venv/bin/activate" ]; then
    echo "📦 Attivazione ambiente virtuale..."
    source venv/bin/activate
else
    echo "❌ Ambiente virtuale non trovato!"
    exit 1
fi

# Verifica che Redis sia in esecuzione
echo "🔍 Verifica Redis..."
if ! redis-cli ping > /dev/null 2>&1; then
    echo "⚠️  Redis non è in esecuzione. Avvio Redis..."
    redis-server --daemonize yes --port 6379
    sleep 2
fi

# Verifica la connessione a Redis
if redis-cli ping > /dev/null 2>&1; then
    echo "✅ Redis connesso e funzionante"
else
    echo "❌ Errore nella connessione a Redis"
    exit 1
fi

# Applica le migrazioni
echo "🗄️  Applicazione migrazioni..."
python manage.py makemigrations
python manage.py migrate

# Raccoglie i file statici
echo "📁 Raccolta file statici..."
python manage.py collectstatic --noinput

# Avvia il server Django con ASGI (WebSocket)
echo "🚀 Avvio server Django con WebSocket su porta 8001..."
echo "📡 WebSocket disponibile su: ws://localhost:8001/ws/admin/"
echo "🌐 Dashboard admin: http://localhost:8001/admin/"
echo ""
echo "Premi Ctrl+C per fermare il server"
echo ""

# Avvia il server ASGI
daphne -b 0.0.0.0 -p 8001 src.asgi:application
