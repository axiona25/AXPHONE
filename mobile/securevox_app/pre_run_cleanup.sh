#!/bin/bash
# Script di cleanup automatico prima del flutter run

echo "🧹 === PRE-RUN CLEANUP AUTOMATICO ==="
echo "⏰ $(date)"

# Vai alla directory del progetto
cd "$(dirname "$0")/../.."

# Esegui cleanup token
echo "🔧 Esecuzione cleanup token..."
python3 scripts/auto_cleanup_tokens.py

echo ""
echo "✅ === CLEANUP COMPLETATO ==="
echo "🚀 Avvio Flutter app..."

# Avvia Flutter
cd mobile/securevox_app
flutter run
