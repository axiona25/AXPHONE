#!/bin/bash

echo "🌐 Configurazione Accesso Pubblico SecureVox"
echo "============================================="

# IP pubblico dell'utente
USER_IP="87.1.146.121"
SERVER_IP="130.110.3.186"
DOMAIN="securevox.it"

echo "📍 IP Pubblico Utente: $USER_IP"
echo "📍 IP Server Oracle: $SERVER_IP"
echo "🌐 Dominio: $DOMAIN"

echo ""
echo "🔧 OPZIONI DISPONIBILI:"
echo "======================="

echo ""
echo "1️⃣  TUNNEL LOCALE (Raccomandato per test)"
echo "   - Installa Cloudflare Tunnel"
echo "   - Esegui: cloudflared tunnel --url http://localhost:8001"
echo "   - Usa l'URL fornito per accedere a SecureVox"

echo ""
echo "2️⃣  DEPLOY SU ORACLE CLOUD (Produzione)"
echo "   - Risolvi problemi SSH"
echo "   - Esegui: scripts/deploy_to_oracle_cloud.sh"
echo "   - Configura DNS per puntare a $SERVER_IP"

echo ""
echo "3️⃣  VPS ALTERNATIVO (Se Oracle non funziona)"
echo "   - DigitalOcean, AWS, Google Cloud"
echo "   - Deploy manuale di SecureVox"

echo ""
echo "📱 CONFIGURAZIONE APP MOBILE:"
echo "============================="

# Crea file di configurazione per le app
cat > mobile_config.json << EOL
{
  "development": {
    "api_base_url": "http://localhost:8001",
    "websocket_url": "ws://localhost:8002",
    "notify_url": "ws://localhost:8003"
  },
  "production": {
    "api_base_url": "https://$DOMAIN",
    "websocket_url": "wss://$DOMAIN:8002",
    "notify_url": "wss://$DOMAIN:8003"
  },
  "tunnel": {
    "api_base_url": "https://YOUR_TUNNEL_URL",
    "websocket_url": "wss://YOUR_TUNNEL_URL:8002",
    "notify_url": "wss://YOUR_TUNNEL_URL:8003"
  }
}
EOL

echo "✅ Configurazione mobile salvata in mobile_config.json"

echo ""
echo "🚀 PROSSIMI PASSI:"
echo "=================="
echo "1. Scegli un'opzione sopra"
echo "2. Configura il tunnel o il deploy"
echo "3. Aggiorna le app mobile con la nuova configurazione"
echo "4. Testa l'accesso pubblico"

echo ""
echo "💡 RACCOMANDAZIONE:"
echo "Per iniziare subito, usa Cloudflare Tunnel:"
echo "1. Installa: brew install cloudflared"
echo "2. Esegui: cloudflared tunnel --url http://localhost:8001"
echo "3. Usa l'URL fornito per accedere a SecureVox"

