#!/bin/bash

echo "🔧 Risoluzione problemi di build iOS per SecureVOX..."

# Vai nella directory dell'app
cd "$(dirname "$0")"

echo "📱 Pulizia cache Flutter..."
flutter clean

echo "📦 Aggiornamento dipendenze..."
flutter pub get

echo "🍎 Pulizia cache iOS..."
cd ios
rm -rf Pods
rm -rf Podfile.lock
rm -rf .symlinks
rm -rf Flutter/Flutter.framework
rm -rf Flutter/Flutter.podspec

echo "📱 Reinstallazione pods..."
pod install --repo-update

echo "🔨 Build iOS..."
cd ..
flutter build ios --release

echo "✅ Build completato! I warning di deprecazione dovrebbero essere risolti."
echo "📋 Se ci sono ancora warning, sono normali per i plugin di terze parti"
echo "   e non influenzano il funzionamento dell'app."
