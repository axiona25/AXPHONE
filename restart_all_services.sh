#!/bin/bash

echo "🔄 RIAVVIO COMPLETO STACK SECUREVOX"
echo "==================================="
echo ""

# Ferma tutti i servizi esistenti
echo "⏹️  Fermando servizi esistenti..."
pkill -f "python manage.py runserver" 2>/dev/null || true
pkill -f "python securevox_notify.py" 2>/dev/null || true  
pkill -f "node src/securevox-call-server.js" 2>/dev/null || true
sleep 2

# Avvia Django API Server
echo "🖥️  Avviando Django API Server (8001)..."
cd /Users/r.amoroso/Desktop/securevox-complete-cursor-pack/server
source venv/bin/activate
python manage.py runserver 0.0.0.0:8001 > /dev/null 2>&1 &
DJANGO_PID=$!
sleep 3

# Avvia Notification Server  
echo "🔔 Avviando Notification Server (8002)..."
python securevox_notify.py > /dev/null 2>&1 &
NOTIFY_PID=$!
sleep 2

# Avvia Call Server
echo "📞 Avviando Call Server (8003)..."
cd /Users/r.amoroso/Desktop/securevox-complete-cursor-pack/call-server
SECUREVOX_CALL_PORT=8003 \
JWT_SECRET=test-secret \
NODE_ENV=development \
HOST=0.0.0.0 \
MAIN_SERVER_URL=http://localhost:8001 \
NOTIFY_SERVER_URL=http://localhost:8002 \
node src/securevox-call-server.js > /dev/null 2>&1 &
CALL_PID=$!
sleep 3

echo ""
echo "✅ TUTTI I SERVIZI AVVIATI!"
echo ""
echo "🔍 Stato servizi:"
echo "   Django API: PID $DJANGO_PID"
echo "   Notification: PID $NOTIFY_PID" 
echo "   Call Server: PID $CALL_PID"
echo ""
echo "🌐 URLs:"
echo "   Dashboard: http://localhost:8001/admin/"
echo "   API Health: http://localhost:8001/health/"
echo "   Notify Health: http://localhost:8002/health"
echo ""
echo "💡 Per verificare lo stato: ./check_services.sh"
