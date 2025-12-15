#!/bin/bash

# Script para gerar APK do Android
# Uso: ./build-apk.sh [debug|release]

BUILD_TYPE=${1:-debug}

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
