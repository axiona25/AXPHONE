#!/bin/bash

echo "🔍 VERIFICA SERVIZI SECUREVOX"
echo "================================"
echo ""

# Django API Server
echo "🖥️  Django API Server (8001):"
if curl -s http://localhost:8001/health/ > /dev/null; then
    echo "    ✅ ONLINE"
    curl -s http://localhost:8001/health/ | jq -r '.service' 2>/dev/null || echo "    API Healthy"
else
    echo "    ❌ OFFLINE"
fi
echo ""

# Notification Server
echo "🔔 Notification Server (8002):"
if curl -s http://localhost:8002/health > /dev/null; then
    echo "    ✅ ONLINE"
    curl -s http://localhost:8002/health | jq -r '.devices_count' 2>/dev/null | xargs -I {} echo "    Dispositivi: {}"
else
    echo "    ❌ OFFLINE"
fi
echo ""

# Call Server
echo "📞 Call Server (8003):"
if curl -s http://localhost:8003/ > /dev/null 2>&1; then
    echo "    ✅ ONLINE"
    echo "    WebRTC Signaling attivo"
else
    echo "    ❌ OFFLINE"
fi
echo ""

# Dashboard
echo "🎛️ Dashboard Admin:"
if curl -s http://localhost:8001/admin/ > /dev/null; then
    echo "    ✅ ACCESSIBILE"
    echo "    URL: http://localhost:8001/admin/"
else
    echo "    ❌ NON ACCESSIBILE"
fi
echo ""

# File statici
echo "📁 File Statici Dashboard:"
if curl -s -I http://localhost:8001/static/admin_panel/dashboard.js | grep "200 OK" > /dev/null; then
    echo "    ✅ JavaScript caricato"
else
    echo "    ❌ JavaScript non trovato"
fi
echo ""

echo "🚀 Verifica completata!"
echo ""
echo "💡 Se la dashboard non funziona:"
echo "   1. Effettua il login: http://localhost:8001/admin/"
echo "   2. Controlla la console del browser (F12)"
echo "   3. Verifica che tutti i servizi siano online"
