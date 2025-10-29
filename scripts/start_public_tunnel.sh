#!/bin/bash

echo "🌐 Avvio tunnel pubblico per SecureVox"
echo "====================================="

# Verifica che i servizi locali siano attivi
echo "🔍 Verificando servizi locali..."
if curl -s http://localhost:8001/ > /dev/null; then
    echo "✅ Django Backend attivo"
else
    echo "❌ Django Backend non attivo - avvialo prima"
    exit 1
fi

if curl -s http://localhost:8002/health > /dev/null; then
    echo "✅ Call Server attivo"
else
    echo "❌ Call Server non attivo - avvialo prima"
    exit 1
fi

if curl -s http://localhost:8003/health > /dev/null; then
    echo "✅ Notify Server attivo"
else
    echo "❌ Notify Server non attivo - avvialo prima"
    exit 1
fi

echo ""
echo "🚀 Avvio tunnel pubblico..."

# Usa un servizio di tunneling alternativo
echo "💡 Opzioni disponibili:"
echo "1. Cloudflare Tunnel (raccomandato)"
echo "2. Serveo (temporaneo)"
echo "3. LocalTunnel"

echo ""
echo "🔧 Configurazione manuale:"
echo "1. Installa Cloudflare Tunnel: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/"
echo "2. Esegui: cloudflared tunnel --url http://localhost:8001"
echo "3. Usa l'URL fornito per accedere a SecureVox"

echo ""
echo "📱 Per le app mobile, aggiorna la configurazione con l'URL del tunnel"
echo "🌐 Il dominio securevox.it punterà al tunnel una volta configurato"

