#!/usr/bin/env bash
set -e

VERSION="0.6.31"
BUILD_NUMBER="999"

echo "=========================================="
echo "🔨 Compilando Kairós Android Split APKs"
echo "   Versão: $VERSION"
echo "   Build:  $BUILD_NUMBER"
echo "=========================================="

# 1. Limpeza prévia
rm -f assets/*.db-wal assets/*.db-shm src/database/data/*.db-wal src/database/data/*.db-shm

# 2. Executa a primeira fase do Flet permitindo capturar o projeto gerado
set +e
flet build apk \
  --yes \
  --build-version "$VERSION" \
  --build-number "$BUILD_NUMBER" \
  --android-permissions REQUEST_INSTALL_PACKAGES=true \
  --split-per-abi \
  -v
BUILD_STATUS=$?
set -e

# 3. Se o build do Flet parar ou requerer ajuste de jni/serious_python (conforme cd.yml)
if [ $BUILD_STATUS -ne 0 ] || [ ! -f "build/apk/*arm64*.apk" ]; then
  echo "⚠️  Ajustando dependências nativas e variáveis do Serious Python..."

  if [ -f "build/flutter/pubspec.yaml" ]; then
    sed -i 's/jni: 1.0.0/jni: ^1.1.0/g' build/flutter/pubspec.yaml
  fi

  find ~/.pub-cache -name "build.gradle.kts" -exec sed -i 's/useETag("all")/\/\/ useETag("all")/g' {} + 2>/dev/null || true
  find . -name "etags.json" -delete 2>/dev/null || true

  export SERIOUS_PYTHON_SITE_PACKAGES="/workspace/build/site-packages"
  export SERIOUS_PYTHON_APP="/workspace/build/python-app"
  export SERIOUS_PYTHON_APP_DIR="/workspace/build/python-app"

  if [ -d "/workspace/build/python-app" ] && [ -f "src/version.py" ]; then
    echo "📝 Copiando src/version.py para /workspace/build/python-app/src/version.py..."
    mkdir -p "/workspace/build/python-app/src"
    cp -f src/version.py "/workspace/build/python-app/src/version.py"
  fi

  echo "🚀 Compilando APKs diretamente via Flutter..."
  cd build/flutter

  flutter pub get

  flutter build apk \
    --split-per-abi \
    --target-platform android-arm64,android-x64,android-arm \
    --build-number "$BUILD_NUMBER" \
    --build-name "$VERSION" \
    --no-version-check \
    --suppress-analytics

  cd ../..

  mkdir -p build/apk
  cp -f build/flutter/build/app/outputs/flutter-apk/*.apk build/apk/
fi

echo "📦 Organizando APKs em release_apks..."
mkdir -p release_apks
ARM64_APK=$(find build/apk -name "*arm64-v8a*.apk" 2>/dev/null | head -n 1)
if [ -n "$ARM64_APK" ]; then
  cp -f "$ARM64_APK" "release_apks/Kairos_${VERSION}_arm64.apk"
  echo "✅ release_apks/Kairos_${VERSION}_arm64.apk"
fi

ARMV7_APK=$(find build/apk -name "*armeabi-v7a*.apk" 2>/dev/null | head -n 1)
if [ -n "$ARMV7_APK" ]; then
  cp -f "$ARMV7_APK" "release_apks/Kairos_${VERSION}_armv7.apk"
  echo "✅ release_apks/Kairos_${VERSION}_armv7.apk"
fi

X86_64_APK=$(find build/apk -name "*x86_64*.apk" 2>/dev/null | head -n 1)
if [ -n "$X86_64_APK" ]; then
  cp -f "$X86_64_APK" "release_apks/Kairos_${VERSION}_x86_64.apk"
  echo "✅ release_apks/Kairos_${VERSION}_x86_64.apk"
fi

echo "=========================================="
echo "🎉 Build concluída com sucesso!"
ls -lh release_apks/
echo "=========================================="
