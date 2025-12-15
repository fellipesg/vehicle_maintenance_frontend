#!/bin/bash

# Script para atualizar dependências e limpar cache
echo "🔄 Atualizando dependências do Flutter..."

# Limpar cache
echo "🧹 Limpando cache..."
flutter clean

# Atualizar dependências
echo "📦 Obtendo dependências atualizadas..."
flutter pub get

# Atualizar para versões mais recentes compatíveis
echo "⬆️  Atualizando para versões mais recentes..."
flutter pub upgrade

echo "✅ Dependências atualizadas!"
echo ""
echo "Agora você pode tentar gerar a APK novamente:"
echo "  flutter build apk --debug"
