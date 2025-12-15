#!/bin/bash

# Script para limpar cache e reconstruir o projeto Android
# Uso: ./clean-and-build.sh [debug|release]

BUILD_TYPE=${1:-debug}

echo "🧹 Limpando cache do Flutter..."
flutter clean

echo "🧹 Limpando cache do Gradle..."
cd android
./gradlew clean --no-daemon
cd ..

echo "📦 Obtendo dependências do Flutter..."
flutter pub get

echo "🔨 Gerando APK do tipo: $BUILD_TYPE"

if [ "$BUILD_TYPE" = "release" ]; then
    echo "📦 Gerando APK de RELEASE..."
    flutter build apk --release
    echo "✅ APK gerada em: build/app/outputs/flutter-apk/app-release.apk"
elif [ "$BUILD_TYPE" = "debug" ]; then
    echo "🐛 Gerando APK de DEBUG..."
    flutter build apk --debug
    echo "✅ APK gerada em: build/app/outputs/flutter-apk/app-debug.apk"
else
    echo "❌ Tipo inválido. Use 'debug' ou 'release'"
    exit 1
fi
