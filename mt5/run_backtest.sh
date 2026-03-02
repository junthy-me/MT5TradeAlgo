#!/bin/zsh
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <config-ini> [report-stem]" >&2
  exit 1
fi

ROOT_DIR="/Users/junthy/Work/MT5TradeAlgo"
WINE_PREFIX="$HOME/Library/Application Support/net.metaquotes.wine.metatrader5"
MT5_DIR="$WINE_PREFIX/drive_c/Program Files/MetaTrader 5"
TERMINAL_EXE="$MT5_DIR/terminal64.exe"
WINE64="/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine64"
TMP_DIR="/tmp/mt5run"

CONFIG_SRC="$1"
REPORT_STEM="${2:-$(basename "${CONFIG_SRC:r}")}"
RUNTIME_CONFIG="$TMP_DIR/${REPORT_STEM}.ini"
LAUNCH_LOG="$TMP_DIR/${REPORT_STEM}.launch.log"

mkdir -p "$TMP_DIR"
printf '\xFF\xFE' > "$RUNTIME_CONFIG"
iconv -f UTF-8 -t UTF-16LE "$CONFIG_SRC" >> "$RUNTIME_CONFIG"
rm -f -- "$TMP_DIR/${REPORT_STEM}" "$TMP_DIR/${REPORT_STEM}.htm" "$TMP_DIR/${REPORT_STEM}.html" \
  "$TMP_DIR/${REPORT_STEM}.xml" "$TMP_DIR/${REPORT_STEM}.report" "$LAUNCH_LOG"

WINEPREFIX="$WINE_PREFIX" WINEDEBUG=-all "$WINE64" "$TERMINAL_EXE" \
  "/config:Z:\\tmp\\mt5run\\${REPORT_STEM}.ini" "/portable" >"$LAUNCH_LOG" 2>&1 &

echo "runtime_config=$RUNTIME_CONFIG"
echo "launch_log=$LAUNCH_LOG"
echo "report_prefix=$TMP_DIR/$REPORT_STEM"
