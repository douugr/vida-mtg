#!/bin/bash
# Compila o LifeCounter para iPad com iOS 8 (armv7) usando o toolchain do Xcode 13.4.1.
# Uso:  ./build.sh            -> gera LifeCounter.ipa
#       ./build.sh install    -> gera e instala no iPad conectado (precisa do AppSync)
set -euo pipefail
cd "$(dirname "$0")"

APP=LifeCounter
ROOT="$(cd .. && pwd)"
X13="${X13:-$ROOT/Xcode-13.4.1.app/Contents/Developer}"
TC="$X13/Toolchains/XcodeDefault.xctoolchain/usr/bin"
SDK="$(ls -d "$X13"/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS*.sdk 2>/dev/null | head -1 || true)"

if [ ! -x "$TC/clang" ] || [ -z "$SDK" ]; then
    echo "Toolchain do Xcode 13 não encontrado em: $X13" >&2
    echo "Extraia o Xcode 13.4.1 em $ROOT/Xcode-13.4.1.app ou defina X13=..." >&2
    exit 1
fi

export DEVELOPER_DIR="$X13"
OUT="build/Payload/$APP.app"
rm -rf build "$APP.ipa"
mkdir -p "$OUT"

echo "==> Compilando (armv7, iOS 8.0) com $(basename "$SDK")"
"$TC/clang" -arch armv7 -isysroot "$SDK" -miphoneos-version-min=8.0 \
    -B "$TC" \
    -fobjc-arc -O2 -Wall -Wno-unused-parameter -Wunguarded-availability \
    src/*.m -o "$OUT/$APP" \
    -framework Foundation -framework UIKit -framework CoreGraphics -framework QuartzCore

cp Info.plist "$OUT/"
cp resources/*.png "$OUT/"

echo "==> Assinando (ad-hoc, o AppSync dispensa assinatura válida)"
if command -v ldid >/dev/null 2>&1; then
    ldid -S "$OUT/$APP"
else
    codesign -f -s - "$OUT/$APP"
fi

(cd build && zip -qry "../$APP.ipa" Payload)
lipo -info "$OUT/$APP"
echo "==> OK: $(pwd)/$APP.ipa"

if [ "${1:-}" = "install" ]; then
    INSTALLER="${IDEVICEINSTALLER:-$(command -v ideviceinstaller || true)}"
    if [ -z "$INSTALLER" ]; then
        INSTALLER="$(find "$HOME/Downloads/Legacy-iOS-Kit_v26/bin/macos" -name ideviceinstaller -type f 2>/dev/null | head -1 || true)"
    fi
    if [ -z "$INSTALLER" ]; then
        echo "ideviceinstaller não encontrado; instale o .ipa pela Legacy-iOS-Kit." >&2
        exit 1
    fi
    echo "==> Instalando com $INSTALLER"
    "$INSTALLER" -i "$APP.ipa" 2>/dev/null || "$INSTALLER" install "$APP.ipa"
fi
